require "http/client"

class LogFetcher
  def self.fetch_logs(job_id : String) : String
    output = IO::Memory.new
    error = IO::Memory.new
    status = Process.run(
      "sh",
      ["-c", "gh run view --job #{job_id} --log | grep 'respirate'"],
      output: output,
      error: error
    )

    unless status.success?
      raise Exception.new("Failed to fetch logs: #{error.to_s}")
    end

    output.to_s.lines.map { |line|
      if line =~ /.*respirate\.\d \| (\{.*\})/
        $1
      end
    }.compact!.join("\n")
  end
end
