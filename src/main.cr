require "./log_fetcher"
require "./log_formatter"

LogFormatter.process_input(ARGV.empty? ? STDIN : LogFetcher.fetch_logs(ARGV[0]))
