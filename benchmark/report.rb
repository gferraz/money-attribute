# frozen_string_literal: true

# Generate a consolidated markdown benchmark report.
# Run: bundle exec ruby benchmark/report.rb

require 'open3'
require 'json'
require 'fileutils'
require 'bundler/setup'
require 'rails'

BENCH_SCRIPT = File.expand_path('comparison.rb', __dir__)
RESULTS_DIR  = File.expand_path('../tmp', __dir__)
FileUtils.mkdir_p(RESULTS_DIR)

SIDES = {
  'minting' => 'money_attribute',
  'money_rails' => 'money-rails'
}.freeze

def run_side(side)
  out_file = File.join(RESULTS_DIR, "bench_#{side}.out")
  env = { 'RAILS_ENV' => 'test', 'BENCH_SIDE' => side }
  cmd = %w[bundle exec ruby] + [BENCH_SCRIPT]

  stdout, stderr, status = Open3.capture3(env, *cmd)
  File.write(out_file, stdout)

  unless status.success?
    warn "Error running #{side}: #{stderr}"
    exit 1
  end

  stdout
end

# Parse Benchmark.bm lines: 3+ space-separated columns ending with (real)
# Example:
#   money_attribute  (single integer):         0.006135   0.000122   0.006257 (  0.006265)
BM_RE = /^\s*(.+?):\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+\(\s*([\d.]+)\)\s*$/

# Parse mass-insert lines:
#   money_attribute (single integer):           0.0295s
MASS_RE = /^\s*(.+?):?\s+([\d.]+)s\s*$/

# Parse allocation lines:
#   money_attribute (comp integer) allocated:          2
ALLOC_RE = /^\s*(.+?) allocated:\s+(\d+)\s*$/

# Parse identity lines:
#   money_attribute composite int same object? true
IDENTITY_RE = /^\s*(.+?)\s+same object\?\s+(true|false)\s*$/

SECTION_HEADERS = {
  /Instantiation/ => :instantiation,
  /Create \+ save/ => :create_save,
  /Read Money attribute/ => :read,
  /Query/ => :query,
  /Arithmetic/ => :arithmetic,
  /Repeated access|Repeated read|caching/ => :caching,
  /Mass insert/ => :mass_insert
}.freeze

def parse_output(text)
  data = { bm: {}, mass: {}, alloc: {}, identity: {} }
  current_section = nil

  text.each_line do |line|
    case line

    when BM_RE
      label = Regexp.last_match(1).strip
      data[:bm][current_section] ||= {}
      data[:bm][current_section][label] = {
        user: Regexp.last_match(2).to_f,
        system: Regexp.last_match(3).to_f,
        total: Regexp.last_match(4).to_f,
        real: Regexp.last_match(5).to_f
      }

    when MASS_RE
      data[:mass][Regexp.last_match(1).strip] = Regexp.last_match(2).to_f

    when ALLOC_RE
      data[:alloc][Regexp.last_match(1).strip] = Regexp.last_match(2).to_i

    when IDENTITY_RE
      data[:identity][Regexp.last_match(1).strip] = Regexp.last_match(2) == 'true'

    else
      SECTION_HEADERS.each do |re, section|
        if line.match?(re)
          current_section = section
          break
        end
      end
    end
  end

  data
end

def compare_val(a, b)
  return '—' if a.nil? || b.nil?
  return '—' if b.zero?

  ratio = a / b
  if ratio > 1
    "#{ratio.round(2)}× slower"
  else
    "#{(1 / ratio).round(2)}× faster"
  end
end

def fmt(val)
  return '—' unless val

  format('%.5f', val)
end

puts 'Running money_attribute benchmark...'
minting_out = run_side('minting')
minting = parse_output(minting_out)

puts 'Running money-rails benchmark...'
rails_out = run_side('money_rails')
rails = parse_output(rails_out)

# ── Generate report ────────────────────────────────────────────

puts "\nGenerating report..."

report = +''
report << "# Benchmark Report: money_attribute vs money-rails\n\n"
report << "Run at: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}\n"
report << "Ruby #{RUBY_VERSION}, Rails #{Rails::VERSION::STRING}\n\n"

report << "## Instantiation (passing Money object to setter)\n\n"
report << "| Variant | minting (s) | money-rails (s) | Comparison |\n"
report << "|---|---|---|---|\n"

rows = [
  ['single integer', 'money_attribute  (single integer)', 'money-rails   (single integer)'],
  ['single decimal', 'money_attribute  (single decimal)', nil],
  ['comp integer',   'money_attribute  (comp integer)',   'money-rails   (comp integer)'],
  ['comp decimal',   'money_attribute  (comp decimal)',   nil]
]
rows.each do |variant, mint_label, rails_label|
  m = minting[:bm][:instantiation][mint_label]
  r = rails[:bm][:instantiation][rails_label] if rails_label
  comp = compare_val(m&.dig(:real), r&.dig(:real))
  report << "| #{variant} | #{fmt(m&.dig(:real))} | #{fmt(r&.dig(:real))} | #{comp} |\n"
end

report << "\n## Create + save individual (Money through setter)\n\n"
report << "| Variant | minting (s) | money-rails (s) | Comparison |\n"
report << "|---|---|---|---|\n"

rows.each do |variant, mint_label, rails_label|
  m = minting[:bm][:create_save][mint_label]
  r = rails[:bm][:create_save][rails_label] if rails_label
  comp = compare_val(m&.dig(:real), r&.dig(:real))
  report << "| #{variant} | #{fmt(m&.dig(:real))} | #{fmt(r&.dig(:real))} | #{comp} |\n"
end

report << "\n## Read Money attribute from persisted record\n\n"
report << "| Variant | minting (s) | money-rails (s) | Comparison |\n"
report << "|---|---|---|---|\n"

rows.each do |variant, mint_label, rails_label|
  m = minting[:bm][:read][mint_label]
  r = rails[:bm][:read][rails_label] if rails_label
  comp = compare_val(m&.dig(:real), r&.dig(:real))
  report << "| #{variant} | #{fmt(m&.dig(:real))} | #{fmt(r&.dig(:real))} | #{comp} |\n"
end

report << "\n## Query (raw column values)\n\n"
report << "| Variant | minting (s) | money-rails (s) | Comparison |\n"
report << "|---|---|---|---|\n"

rows.each do |variant, mint_label, rails_label|
  m = minting[:bm][:query][mint_label]
  r = rails[:bm][:query][rails_label] if rails_label
  comp = compare_val(m&.dig(:real), r&.dig(:real))
  report << "| #{variant} | #{fmt(m&.dig(:real))} | #{fmt(r&.dig(:real))} | #{comp} |\n"
end

report << "\n## Arithmetic (add two money attributes)\n\n"
report << "Only money_attribute has decimal-amount arithmetic; money-rails stores cents (integer).\n\n"
report << "| Variant | minting (s) |\n"
report << "|---|---|\n"
report << "| single integer | #{fmt(minting[:bm][:arithmetic]['money_attribute  (single integer)']&.dig(:real))} |\n"

report << "\n## Repeated access (caching demonstration)\n\n"
report << "| Property | money_attribute | money-rails |\n"
report << "|---|---|---|\n"
report << "| composite int same object? | #{minting[:identity]['money_attribute composite int']} | #{rails[:identity]['money-rails   composite int']} |\n"
report << "| composite dec same object? | #{minting[:identity]['money_attribute composite dec']} | — |\n"
report << "| Repeated read (real, s) | #{fmt(minting[:bm][:caching]['money_attribute  (comp integer)']&.dig(:real))} | #{fmt(rails[:bm][:caching]['money-rails   (comp integer)']&.dig(:real))} |\n"
report << "| Repeated read decimal (real, s) | #{fmt(minting[:bm][:caching]['money_attribute  (comp decimal)']&.dig(:real))} | — |\n"

alloc_mint_int = minting[:alloc]['money_attribute (comp integer)']
alloc_mint_dec = minting[:alloc]['money_attribute (comp decimal)']
alloc_rails    = rails[:alloc]['money-rails (comp integer)']
report << "| Objects allocated per read | #{alloc_mint_int} | #{alloc_rails} |\n"
report << "| Objects allocated per read (decimal) | #{alloc_mint_dec} | — |\n"

report << "\n## Mass insert (100 records in transaction)\n\n"
report << "| Variant | minting (s) | money-rails (s) | Comparison |\n"
report << "|---|---|---|---|\n"

mass_rows = [
  ['single integer', 'money_attribute (single integer)', 'money-rails  (single integer)'],
  ['single decimal', 'money_attribute (single decimal)', nil],
  ['comp integer',   'money_attribute (comp integer)',   'money-rails  (comp integer)'],
  ['comp decimal',   'money_attribute (comp decimal)',   nil]
]
mass_rows.each do |variant, mint_label, rails_label|
  m = minting[:mass][mint_label]
  r = rails[:mass][rails_label] if rails_label
  comp = compare_val(m, r)
  report << "| #{variant} | #{fmt(m)} | #{fmt(r)} | #{comp} |\n"
end

report << "\n## Environment\n\n"
report << "- Ruby: #{RUBY_VERSION}\n"
report << "- Rails: #{Rails::VERSION::STRING}\n"
report << "- SQLite3\n"
report << "- Iterations per test: 5.000\n"
report << "- Records for mass insert: 1.000\n"
report << "- Both sides pass a Money object through the attribute setter\n"
report << "- Each side runs in a separate process (no gem conflict)\n"

report_path = File.join(RESULTS_DIR, 'benchmark_report.md')
File.write(report_path, report)
puts "Report written to #{report_path}"
