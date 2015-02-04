require "faraday"
require "net/http/post/multipart"
require "json"
require "yaml"
require "pry"

module SearchMe
  class RequestSession
    QUERY_COUNTS = {:easy => 5, :medium => 5}
    DIFFICULTY_LEVELS = [:easy, :medium]
    PAR_FACTOR = 1

    attr_reader :server_address,
                :index,
                :index_times,
                :query_times,
                :query_results

    def initialize(server_address)
      @server_address = server_address
      @index_times = []
      @query_times = []
      @query_results = {:easy => {}, :medium => {}}
      @index = {:easy => {}, :medium => {}}
    end

    def build_index!
      start = Time.now
      source_files.each do |f_path|
        filename = f_path.split("/").last
        File.readlines(f_path).each_with_index do |line, l_index|
          line.split(/ |-|—/).each_with_index do |word, w_index|
            word = tokenize(word)
            if index[word].nil?
              index[word] = ["#{filename}:#{l_index}:#{w_index}"]
            else
              index[word] << "#{filename}:#{l_index}:#{w_index}"
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
      #clear server's existing index
      Faraday.delete("#{server_address}/index")

      index_queue = Queue.new
      source_files.each { |path| index_queue.push(path) }

      PAR_FACTOR.times do
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

    def run_queries(difficulty)
      puts "Will perform #{QUERY_COUNTS[difficulty]} queries on Difficulty: #{difficulty}"
      q = Queue.new

      QUERY_COUNTS[difficulty].times do
        q.push(index[difficulty].keys.sample)
      end

      PAR_FACTOR.times do |i|
        Thread.new do
          begin
            while query = q.pop(true)
              puts "query #{query}"
              start = Time.now
              result = JSON.parse(Faraday.post("#{server_address}/query", {query: query}).body)
              query_times << (Time.now - start)
              query_results[difficulty][query] = result
            end
          rescue ThreadError
            puts "#{difficulty} query queue empty, stopping query thread"
          end
        end.join
      end
    end

    def output_results(difficulty)
      puts "Congrats, #{difficulty} queries completed"
      puts "indexed #{source_files.count} files in average of #{index_times.reduce(:+)/index_times.length} seconds"
      puts "total index time: #{index_times.reduce(:+)}"

      puts "performed 100 queries in average of #{query_times.reduce(:+)/query_times.length} seconds"
      correct = []
      incorrect = []
      query_results.each do |diff, results|
        results.each do |query, result|
          if result.sort == index[diff][query].to_a.sort
            correct << query
          else
            puts "incorrect results for query #{query}; got: #{result}; should have been: #{index[diff][query]}"
            incorrect << query
          end
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
      run_queries(:easy)
      run_queries(:medium)
      output_results(:easy)
      output_results(:medium)
    end

    def load_samples
      puts "load samples"
      @index[:easy] = Hash[YAML.load(File.read(File.join(__dir__, "..", "..", "indices", "easy_queries.yml")))]
      @index[:medium] = YAML.load(File.read(File.join(__dir__, "..", "..", "indices", "medium_queries.yml")))
    end

    def source_files
      Dir.glob(File.join(__dir__, "..", "..", "sanitized_files", "*"))
    end
  end
end
