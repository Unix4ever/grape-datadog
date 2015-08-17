require 'spec_helper'

describe Grape::Datadog::Middleware do

  class TestAPI < Grape::API
    use Grape::Datadog::Middleware,
      hostname: "test.host",
      tags:     ["custom:tag", lambda {|env| "scheme:#{Rack::Request.new(env).scheme}" }]

    get 'echo/:key1/:key2' do
      "#{params['key1']} #{params['key2']}"
    end
  end

  def app; TestAPI; end

  before { $statsd.buffer.clear }

  it 'should be configurable' do
    subject = described_class.new(nil, hostname: "test.host")
    expect(subject.instance_variable_get(:@tags)).to eq(["host:test.host"])
    expect(subject.instance_variable_get(:@statsd)).to be_instance_of(MockStatsd)

    subject = described_class.new(nil, prefer_global: false)
    expect(subject.instance_variable_get(:@statsd)).to be_instance_of(Statsd)
  end

  it 'should send an increment and timing event for each request' do
    get '/echo/1/1234'
    expect(last_response.status).to eq(200)
    expect(last_response.body).to eq('1 1234')

    expect($statsd.buffer).to eq([
      "grape.request:1|c|#custom:tag,scheme:http,host:test.host,method:GET,path:echo.{key1}.{key2},status:200",
      "grape.request.time:333|ms|#custom:tag,scheme:http,host:test.host,method:GET,path:echo.{key1}.{key2},status:200"
    ])
  end
end
