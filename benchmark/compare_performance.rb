# frozen_string_literal: true

# Compare two results produced by benchmark/performance.rb.
#
# Run with:
#   bundle exec ruby benchmark/compare_performance.rb baseline.json current.json

require 'json'

baseline_path, current_path = ARGV
abort 'Usage: compare_performance.rb BASELINE.json CURRENT.json' unless baseline_path && current_path

baseline = JSON.parse(File.read(baseline_path)).fetch('results')
current = JSON.parse(File.read(current_path)).fetch('results')

baseline_metadata = JSON.parse(File.read(baseline_path))
current_metadata = JSON.parse(File.read(current_path))
lines = []
lines << format('%-42s %12s %12s %10s', 'Case', 'Baseline', 'Current', 'Change')
lines << '-' * 80

(baseline.keys | current.keys).sort.each do |label|
  before = baseline.dig(label, 'seconds')
  after = current.dig(label, 'seconds')

  if before && after
    change = ((before - after) / before) * 100
    lines << format('%-42s %10.6fs %10.6fs %+.2f%%', label, before, after, change)
  elsif baseline.dig(label, 'objects') && current.dig(label, 'objects')
    before = baseline.dig(label, 'objects')
    after = current.dig(label, 'objects')
    change = ((before - after).fdiv(before)) * 100
    lines << format('%-42s %12d %12d %+.2f%%', label, before, after, change)
  else
    lines << format('%-42s %12s %12s %10s', label, before || 'missing', after || 'missing', 'n/a')
  end
end

puts lines.join("\n")

if (report_path = ENV['PERFORMANCE_REPORT'])
  markdown = <<~MARKDOWN
    # Performance Comparison

    - Baseline: `#{baseline_path}`
    - Current: `#{current_path}`
    - Ruby: #{current_metadata['ruby']}
    - Rails: #{current_metadata['rails']}

    Positive percentages indicate that the current implementation is faster or
    allocates fewer objects. Negative percentages indicate a regression.

    | Case | Baseline | Current | Change |
    |---|---:|---:|---:|
  MARKDOWN

  lines.drop(2).each do |line|
    fields = line.split
    markdown << "| #{fields[0...-3].join(' ')} | #{fields[-3]} | #{fields[-2]} | #{fields[-1]} |\n"
  end

  File.write(report_path, markdown)
  puts "\nMarkdown report written to #{report_path}"
end
