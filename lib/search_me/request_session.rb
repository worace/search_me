require "faraday"
require "net/http/post/multipart"
require "json"

module SearchMe
  class RequestSession
    attr_reader :server_address,
                :index,
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
      @index = {}
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
      source_files.each { |path| index_queue.push(path) }

      (0..difficulty).each do
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

      500.times { q.push(index.keys.sample) }

      (0..difficulty).each do |i|
        Thread.new do
          begin
            while word = q.pop(true)
              answer = index[word]
              puts "will query against word \"#{word}\""
              puts "and expect result #{answer}"
              start = Time.now
              result = JSON.parse(Faraday.post("#{server_address}/query", {query: word}).body)
              query_times << (Time.now - start)
              query_results[word] = result
            end
          rescue ThreadError
            puts "query queue empty, stopping query thread"
          end
        end.join
      end
    end

    def output_results
      puts "indexed #{source_files.count} files in average of #{index_times.reduce(:+)/index_times.length} seconds"
      puts "performed 100 queries in average of #{query_times.reduce(:+)/query_times.length} seconds"
      correct = []
      incorrect = []
      query_results.each do |word, results|
        if (results - @index[word]).count == 0
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
      build_index!
      prep
      run_queries
      output_results
    end

    def source_files
      Dir.glob("./source_files/*")
    end
  end
end

# Prep phase
# 45s ? 60s?
# bronze/silver/gold for index time?
# send N files successively
# contestant must index files
# Search phase
# choose random file random line random word position
# send word
# verify client response match
#
# Throughput/resp time thresholds ??
# bronze / silver / gold?
#
#file = source_files.sample
#lines = File.readlines(file)
#line_index = rand(lines.length)
##puts "words: #{lines[line_index].split}"
#word_index = rand(lines[line_index].split.length).to_i
#word = lines[line_index].split[word_index]
