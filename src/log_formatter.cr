require "json"
require "colorize"
require "time"

class LogFormatter
  def self.process_input(input : IO | String)
    input.each_line { |line| process_line(line) }
  end

  def self.indent(text : String, level : Int32)
    text.lines.map { |line| "  " * level + line }.join("\n")
  end

  def self.process_line(line)
    json = JSON.parse(line)
    raise "Expect a JSON object" unless (log = json.as_h?)

    if log.has_key?("exception") && (exception = log["exception"])
      message = "Exception: #{exception["class"]} - #{exception["message"]}".colorize(:red).bold
      if (bt = exception["backtrace"]?.try(&.as_a?))
        bt.each do |line|
          cleaned = line.to_s.sub(/^.*?(ubicloud)\//, "").sub(/^.*(lib)\//, "")
          message = "#{message}\n    #{"#{cleaned}".colorize(:red).dim}"
        end
      end
    elsif log.has_key?("ssh") && (ssh = log["ssh"])
      unless ssh["cmd"].to_s.includes?("\n")
        message = "Command".colorize(:light_blue).bold.to_s + " `#{ssh["cmd"]}` exited with #{ssh["exit_code"]} in #{ssh["duration"].as_f.round(2)} seconds".colorize(:light_blue).to_s
      else
        message = "SSH command exited with #{ssh["exit_code"]} in #{ssh["duration"].as_f.round(2)} seconds".colorize(:light_blue)
        message = "#{message}\n#{indent("Command:", 2).colorize(:light_blue).bold}"
        message = "#{message}\n#{indent(ssh["cmd"].to_s, 3).colorize(:light_blue).dim}"
      end
      if (sout = ssh["stdout"].to_s.strip) && !sout.empty?
        message = "#{message}\n#{indent("STDOUT:", 2).colorize(:light_blue).bold}"
        if sout.includes?("\n")
          message = "#{message}\n#{indent(sout, 3).colorize(:light_blue).dim}"
        else
          message = "#{message} #{sout.colorize(:light_blue).dim}"
        end
      end
      if (serr = ssh["stderr"].to_s.strip) && !serr.empty?
        message = "#{message}\n#{indent("STDERR:", 2).colorize(:light_blue).bold}"
        if serr.includes?("\n")
          message = "#{message}\n#{indent(serr, 3).colorize(:light_blue).dim}"
        else
          message = "#{message} #{serr.colorize(:light_blue).dim}"
        end
      end
    elsif log.has_key?("strand_hopped")
      message = "hopped #{log["strand_hopped"]["from"].to_s.ljust(48)} -> #{log["strand_hopped"]["to"]}".colorize(:light_green)
    elsif log.has_key?("strand_exited")
      message = "exited from #{log["strand_exited"]["from"]}".colorize(:light_green)
    elsif log.has_key?("strand_finished")
      message = "strand #{log["strand_finished"]["prog_label"]} finished in #{log["strand_finished"]["duration"].as_f.round(2)} seconds".colorize.dim
    elsif log.has_key?("sleep_duration_sec") || log.has_key?("lease_cleared") || log.has_key?("lease_acquired")
      return
    elsif log.has_key?("lack_of_capacity")
      message = "No capacity left: #{["location", "family", "arch"].map { |k| log["lack_of_capacity"][k] }.join("-")}"
    else
      message = "#{log["message"]}\n"
      if (details = log.reject("time", "message", "thread")) && !details.empty?
        message = "#{message} #{details.colorize.dim}"
      end
    end

    timestamp = log["time"].to_s.sub(/ \+.*$/, "")
    thread = " [#{log["thread"]}] ".colorize(:dark_gray) if log.has_key?("thread")

    puts "#{timestamp.colorize(:light_gray).dim}#{thread}#{message}"
  rescue e
    puts "Invalid JSON log: #{e.message}".colorize(:red).bold
    puts line.colorize.dim
  end
end
