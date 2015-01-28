require "sinatra"
class SampleServer < Sinatra::Base
  configure do
  end

  post "/query" do
    puts "received query request #{params}"
  end

  post "/index" do
    puts "Received index request: #{params.inspect}"
    name = params["file"][:filename]
    path = params["file"][:tempfile]
    index_file(name, path)
  end

  def index_file(filename, filepath)
    puts "file #{filepath} contents:"
    text = File.read(filepath)
    puts text
    puts "lines: #{text.split("\n").count}"
  end
end
