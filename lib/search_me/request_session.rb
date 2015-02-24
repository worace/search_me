require "faraday"
require "net/http/post/multipart"
require "json"
require "yaml"
require "pry"
require_relative "./source_file_list"

module SearchMe
  class StepFailedError < StandardError
    attr_reader :step
    def initialize(step)
      @step = step
    end
  end

  class RequestSession
    QUERY_COUNTS = {:easy => 300, :medium => 75}
    DIFFICULTY_LEVELS = [:easy, :medium]

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

    def clear_index
      puts "Clear index"
      unless Faraday.delete("#{server_address}/index").success?
        raise StepFailedError.new("clear index"), "Server must respond to DELETE '/index' by clearing existing index"
      end
    rescue Faraday::ConnectionFailed
      raise StepFailedError.new("CLEAR INDEX"), "Server must respond to DELETE '/index' by clearing existing index"
    end

    def build_index(files = source_files)
      puts "Build index"

      files.each do |f_path|
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
    end

    def run_queries(difficulty, num_queries)
      puts "*******************************************"
      puts "Will perform #{num_queries} queries on Difficulty: #{difficulty}"

      num_queries.times do
        query = index[difficulty].keys.sample
        track_query(difficulty, query)
      end
      puts "Queries on difficulty: #{difficulty} completed"
      puts "*******************************************"
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

    def run_mini
      @index = {:easy => {"comedy" => ["BGaEaa:353:8","BGaEab:0:1", "BGaEab:874:2"]},
                :medium => {"is a reprint of the" => ["BGaEaa:6:2"],
                            "refined comedy of european christianity" => ["BGaEab:874:1"]}
               }
      files = source_files.first(2)
      clear_index
      build_index(files)
      output_index_results
      run_queries(:easy, 2)
      output_results(:easy)
      run_queries(:medium, 2)
      output_results(:medium)
    rescue StepFailedError => ex
      puts "Failure on step: #{ex.step}. Problem: #{ex.message}"
    end

    def run
      load_samples
      clear_index
      build_index
      output_index_results
      run_queries(:easy, QUERY_COUNTS[:easy])
      output_results(:easy)
      run_queries(:medium, QUERY_COUNTS[:medium])
      output_results(:medium)
    rescue StepFailedError => ex
      puts "Failure on step: #{ex.step}. Problem: #{ex.message}"
    end

    def load_samples
      @index[:easy] = Hash[YAML.load(File.read(File.join(__dir__, "..", "..", "indices", "easy_queries.yml")))]
      @index[:medium] = YAML.load(File.read(File.join(__dir__, "..", "..", "indices", "medium_queries.yml")))
    end

    def source_files
      SourceFileList.new.files
    end
  end
end
