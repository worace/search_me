require "faraday"
require "net/http/post/multipart"
require "json"
require "yaml"
require "pry"

module SearchMe
  class StepFailedError < StandardError
    attr_reader :step
    def initialize(step)
      @step = step
    end
  end
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
      @query_times = {:easy => [], :medium => []}
      @query_results = {:easy => {}, :medium => {}}
      @index = {:easy => {}, :medium => {}}
    end

    def build_index!
      start = Time.now
      source_files.each do |f_path|
        filename = f_path.split("/").last
        File.readlines(f_path).each_with_index do |line, l_index|
          line.split.each_with_index do |word, w_index|
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

    def clear_index
      puts "Clear index"
      unless Faraday.delete("#{server_address}/index").success?
        raise StepFailedError.new("clear index"), "Server must respond to DELETE '/index' by clearing existing index"
      end
    rescue Faraday::ConnectionFailed
      raise StepFailedError.new("CLEAR INDEX"), "Server must respond to DELETE '/index' by clearing existing index"
    end

    def build_index
      puts "Build index"
      index_queue = Queue.new
      source_files.each { |path| index_queue.push(path) }

      PAR_FACTOR.times do
        Thread.new do
          begin
            while f_path = index_queue.pop(true)
              puts "indexing file: #{f_path.split("/").last}"
              start = Time.now
              url = URI.parse("#{server_address}/index")
              File.open(f_path) do |file|
                req = Net::HTTP::Post::Multipart.new url.path,
                  "file" => UploadIO.new(file, "text", f_path.split("/").last)
                res = Net::HTTP.start(url.host, url.port) do |http|
                  http.request(req)
                end
                unless res.kind_of?(Net::HTTPOK)
                  raise StepFailedError.new("Index Files"), "Failed indexing file: #{f_path.split("/").last}\n Reason: #{res.inspect}"
                end
              end
              index_times << (Time.now - start)
            end
          rescue ThreadError
          end
        end.join
      end
    end

    def run_queries(difficulty)
      puts "*******************************************"
      puts "Will perform #{QUERY_COUNTS[difficulty]} queries on Difficulty: #{difficulty}"
      q = query_queue(difficulty)

      PAR_FACTOR.times do |i|
        Thread.new do
          begin
            while query = q.pop(true)
              track_query(difficulty, query)
            end
          rescue ThreadError
          end
        end.join
      end
      puts "Queries on difficulty: #{difficulty} completed"
      puts "*******************************************"
    end

    def query_queue(difficulty)
      q = Queue.new
      QUERY_COUNTS[difficulty].times do
        q.push(index[difficulty].keys.sample)
      end
      q
    end

    def track_query(difficulty, query)
      start = Time.now
      response = Faraday.post("#{server_address}/query", {query: query})
      unless response.success?
        raise StepFailedError.new("Queries: #{difficulty}"), "Query failed with status: #{response.status}, #{response.body}"
      end
      result = JSON.parse(response.body)
      query_times[difficulty] << (Time.now - start)
      query_results[difficulty][query] = result
    end

    def output_results(difficulty)
      correct = []
      incorrect = []
      query_results[difficulty].each do |query, result|
        if result.sort == index[difficulty][query].to_a.sort
          correct << query
        else
          incorrect << query
        end
      end

      puts "*******************************************"
      puts "performed #{QUERY_COUNTS[difficulty]} queries in average of #{query_times[difficulty].reduce(:+)/query_times[difficulty].length} seconds"
      puts "Status: #{incorrect.any? ? "FAILURE" : "SUCCESS"}"
      puts "correct queries: #{correct.count}"
      puts "incorrect: #{incorrect.count}"
      puts "success ratio: #{incorrect.any? ? (correct.count / incorrect.count) : "100" }%"
      puts "*******************************************"

      if incorrect.any?
        raise StepFailedError.new("Queries (#{difficulty})"), "Sorry, you failed #{difficulty}."
      end
    end

    def output_index_results
      puts "*******************************************"
      puts "Congrats: Indexing Completed!"
      puts "total index time: #{index_times.reduce(:+)}"
      puts "indexed #{source_files.count} files in average of #{index_times.reduce(:+)/index_times.length} seconds"
      puts "*******************************************"
    end

    def run
      load_samples
      clear_index
      build_index
      output_index_results
      run_queries(:easy)
      output_results(:easy)
      run_queries(:medium)
      output_results(:medium)
    rescue StepFailedError => ex
      puts "Failure on step: #{ex.step}. Problem: #{ex.message}"
    end

    def load_samples
      @index[:easy] = Hash[YAML.load(File.read(File.join(__dir__, "..", "..", "indices", "easy_queries.yml")))]
      @index[:medium] = YAML.load(File.read(File.join(__dir__, "..", "..", "indices", "medium_queries.yml")))
    end

    def source_files
      Dir.glob(File.join(__dir__, "..", "..", "sanitized_files", "*"))
    end
  end
end
