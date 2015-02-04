require "faraday"
require "net/http/post/multipart"
require "json"
require "yaml"

module SearchMe
  class RequestSession
    EASY_QUERY_COUNT = 5
    attr_reader :server_address,
                :easy_index,
                :index_times,
                :query_times,
                :query_results,
                :difficulty

    def initialize(server_address, difficulty = 2)
      @difficulty = difficulty
      @server_address = server_address
      @index_times = []
      @query_times = []
      @query_results = {}
      @easy_index = {}
    end

    def build_index!
      start = Time.now
      source_files.each do |f_path|
        filename = f_path.split("/").last
        File.readlines(f_path).each_with_index do |line, l_index|
          line.split(/ |-|—/).each_with_index do |word, w_index|
            word = tokenize(word)
            if index[word].nil?
              index[word] = ["#{filename}:#{l_index + 1}:#{w_index + 1}"]
            else
              index[word] << "#{filename}:#{l_index + 1}:#{w_index + 1}"
            end
          end
        end
      end
      puts "made an index in #{Time.now - start} seconds"
    end

    def tokenize(word)
      word.downcase.gsub(/\W|_/,"")
    end

    def prep
      index_queue = Queue.new
      source_files.first(1).each { |path| index_queue.push(path) }

      (0...difficulty).each do
        Thread.new do
          begin
            while f_path = index_queue.pop(true)
              start = Time.now
              url = URI.parse("#{server_address}/index")
              File.open(f_path) do |file|
                req = Net::HTTP::Post::Multipart.new url.path,
                  "file" => UploadIO.new(file, "text", f_path.split("/").last)
                res = Net::HTTP.start(url.host, url.port) do |http|
                  http.request(req)
                end
                puts res
              end
              index_times << (Time.now - start)
            end
          rescue ThreadError
            puts "index queue empty, stopping indexer thread"
          end
        end.join
      end
      puts "finished prep!"
    end

    def run_queries
      q = Queue.new

      EASY_QUERY_COUNT.times do
        q.push(easy_index.keys.sample)
      end

      difficulty.times do |i|
        Thread.new do
          begin
            while query = q.pop(true)
              puts "query #{query}"
              start = Time.now
              result = JSON.parse(Faraday.post("#{server_address}/query", {query: query}).body)
              query_times << (Time.now - start)
              query_results[query] = result
            end
          rescue ThreadError
            puts "query queue empty, stopping query thread"
          end
        end.join
      end
    end

    def run_multiword_queries
      puts @med_index
    end

    def output_results
      puts "Congrats, you finished a search_me session on difficulty level #{difficulty}"
      puts "indexed #{source_files.count} files in average of #{index_times.reduce(:+)/index_times.length} seconds"
      puts "total index time: #{index_times.reduce(:+)}"
      puts "performed 100 queries in average of #{query_times.reduce(:+)/query_times.length} seconds"
      correct = []
      incorrect = []
      query_results.each do |word, results|
        if results.sort == @easy_index[word].sort
          correct << word
        else
          incorrect << word
        end
      end

      puts "correct queries: #{correct.count}"
      puts "incorrect: #{incorrect.count}"
      puts "success ratio: #{incorrect.any? ? (correct.count / incorrect.count) : "100" }%"

      if incorrect.any?
        puts "incorrect words: #{incorrect}"
      end
    end

    def run
      load_samples
      prep
      run_queries
      run_multiword_queries
      #output_results
    end

    def load_samples
      puts "load samples"
      @easy_index = Hash[YAML.load(File.read(File.join(__dir__, "..", "..", "indices", "samples.yml")))]
      @med_index = YAML.load(File.read(File.join(__dir__, "..", "..", "indices", "multiword_samples.yml")))
    end

    def source_files
      Dir.glob(File.join(__dir__, "..", "..", "source_files", "*"))
    end
  end
end
