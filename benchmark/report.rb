# frozen_string_literal: true

# Generate a consolidated markdown benchmark report.
# Run: bundle exec ruby benchmark/report.rb

require 'open3'
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
BM_RE = /^\s*(.+?):\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+\(\s*([\d.]+)\)\s*$/

# Parse allocation lines:
ALLOC_RE = /^\s*(.+?) allocated:\s+(\d+)\s*$/

# Parse identity lines:
IDENTITY_RE = /^\s*(.+?)\s+same object\?\s+(true|false)\s*$/

# Parse scaling lines (minting side: 4 values + label):
#   100:     0.0081s            0.0126s            0.0092s            0.0136s
SCALING_MINT_RE = /^\s*(\d+):\s+([\d.]+)s\s+([\d.]+)s\s+([\d.]+)s\s+([\d.]+)s\s*$/

# Parse scaling lines (money_rails side: 2 values + label):
#   100:     0.0135s            0.021s
SCALING_MR_RE = /^\s*(\d+):\s+([\d.]+)s\s+([\d.]+)s\s*$/

SECTION_HEADERS = {
  /Instantiation/ => :instantiation,
  /Create \+ save/ => :create_save,
  /Update existing/ => :update_existing,
  /Setter only/ => :setter_only,
  /Read Money attribute/ => :read,
  /Query by raw columns/ => :query_raw,
  /Query by Money object/ => :query_money_object,
  /SQL generation/ => :sql_gen,
  /multi-record/ => :multi_record,
  /Arithmetic/ => :arithmetic,
  /Repeated access|caching/ => :caching,
  /Scaling/ => :scaling
}.freeze

def detect_section(line)
  SECTION_HEADERS.each do |re, section|
    return section if line.match?(re)
  end
  nil
end

def parse_benchmark_line(line, data, section)
  m = line.match(BM_RE)
  return unless m

  label = m[1].strip
  data[:bm][section] ||= {}
  data[:bm][section][label] = {
    user: m[2].to_f, system: m[3].to_f, total: m[4].to_f, real: m[5].to_f
  }
end

def parse_scaling_mint_line(line, data)
  m = line.match(SCALING_MINT_RE)
  return unless m

  size = m[1].to_i
  data[:scaling][:insert] << { size:, int: m[2].to_f, dec: m[4].to_f }
  data[:scaling][:update] << { size:, int: m[3].to_f, dec: m[5].to_f }
end

def parse_scaling_mr_line(line, data)
  m = line.match(SCALING_MR_RE)
  return unless m

  size = m[1].to_i
  data[:scaling][:insert] << { size:, mr: m[2].to_f }
  data[:scaling][:update] << { size:, mr: m[3].to_f }
end

def parse_alloc_line(line, data)
  m = line.match(ALLOC_RE)
  return unless m

  data[:alloc][m[1].strip] = m[2].to_i
end

def parse_identity_line(line, data)
  m = line.match(IDENTITY_RE)
  return unless m

  data[:identity][m[1].strip] = m[2] == 'true'
end

def parse_output(text)
  data = { bm: {}, mass: {}, alloc: {}, identity: {}, scaling: { insert: [], update: [] } }
  current_section = nil
  in_scaling = false

  text.each_line do |line|
    section = detect_section(line)
    if section
      current_section = section
      in_scaling = (section == :scaling)
      next
    end

    if in_scaling
      parse_scaling_mint_line(line, data)
      parse_scaling_mr_line(line, data)
      next
    end

    parse_benchmark_line(line, data, current_section)
    parse_alloc_line(line, data)
    parse_identity_line(line, data)
  end

  data
end

def ratio(val_a, val_b)
  return nil if val_a.nil? || val_b.nil? || val_b.zero?

  val_a < val_b ? format('%.1f× faster', val_b / val_a) : format('%.1f× slower', val_a / val_b)
end

def fmt(val)
  return '—' unless val

  format('%.5f', val)
end

def fmt2(val)
  return '—' unless val

  format('%.4f', val)
end

INT  = 'money_attribute (integer column)'
DEC  = 'money_attribute (decimal column)'
MR   = 'money-rails (integer cents)'
MRQ  = 'money-rails (integer cents, currency)'

def bm_val(data, section, label)
  data.dig(:bm, section, label, :real)
end

def section_table(data, section, title, dec_label: DEC, mr_label: MR)
  m_i = bm_val(data[:mint], section, INT)
  m_d = dec_label ? bm_val(data[:mint], section, dec_label) : nil
  r   = mr_label ? bm_val(data[:mr], section, mr_label) : nil
  comp = ratio(m_i, r)

  report = +''
  report << "## #{title}\n\n"
  report << "| Variant | money_attribute (int) | money_attribute (dec) | money-rails | Comparison |\n"
  report << "|---|---|---|---|---|\n"
  report << "| integer column | #{fmt(m_i)} | #{fmt(m_d)} | #{fmt(r)} | #{comp} |\n"
  report << "\n"
  report
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
report << "Run at: #{Time.zone.now.strftime('%Y-%m-%d %H:%M:%S')}\n"
report << "Ruby #{RUBY_VERSION}, Rails #{Rails::VERSION::STRING}\n\n"

# 1. Instantiation
report << section_table({ mint: minting, mr: rails }, :instantiation, 'Instantiation')

# 2. Create + save
report << section_table({ mint: minting, mr: rails }, :create_save, 'Create + save')

# 3. Update existing
report << section_table({ mint: minting, mr: rails }, :update_existing, 'Update existing record')

# 4. Setter only
report << section_table({ mint: minting, mr: rails }, :setter_only, 'Setter only (no DB write)')

# 5. Read cached
report << section_table({ mint: minting, mr: rails }, :read, 'Read from cached record')

# 6. Query raw columns
report << section_table({ mint: minting, mr: rails }, :query_raw, 'Query by raw columns', mr_label: MRQ)

# 7. Query Money object (money_attribute only)
m_val_obj_i = bm_val(minting, :query_money_object, INT)
m_val_obj_d = bm_val(minting, :query_money_object, DEC)
report << "## Query by Money object (composed_of decomposition)\n\n"
report << "Only money_attribute supports this — money-rails cannot decompose `Money` in WHERE clauses.\n\n"
report << "| Variant | money_attribute |\n"
report << "|---|---|\n"
report << "| integer column | #{fmt(m_val_obj_i)} |\n"
report << "| decimal column | #{fmt(m_val_obj_d)} |\n\n"

# 8. SQL generation
report << section_table({ mint: minting, mr: rails }, :sql_gen, 'SQL generation (.to_sql)', mr_label: MRQ)

# 9. Multi-record query
report << section_table({ mint: minting, mr: rails }, :multi_record, 'Multi-record query (100 records × 1000 iters)')

# 10. Arithmetic
m_arith = bm_val(minting, :arithmetic, INT)
report << "## Arithmetic\n\n"
report << "| Variant | money_attribute |\n"
report << "|---|---|\n"
report << "| integer column | #{fmt(m_arith)} |\n\n"

# 11. Caching
m_int_same = minting.dig(:identity, 'money_attribute composite int')
m_dec_same = minting.dig(:identity, 'money_attribute composite dec')
mr_same    = rails.dig(:identity, 'money-rails composite int')
m_cache_i  = bm_val(minting, :caching, INT)
m_cache_d  = bm_val(minting, :caching, DEC)
mr_cache   = bm_val(rails, :caching, MR)
m_alloc_i  = minting.dig(:alloc, 'money_attribute (integer column)')
m_alloc_d  = minting.dig(:alloc, 'money_attribute (decimal column)')
mr_alloc   = rails.dig(:alloc, 'money-rails (integer cents)')

report << "## Caching\n\n"
report << "| Property | money_attribute (int) | money_attribute (dec) | money-rails |\n"
report << "|---|---|---|---|\n"
report << "| Same object on repeated read? | #{m_int_same} | #{m_dec_same} | #{mr_same} |\n"
report << "| Repeated read ×5000 | #{fmt(m_cache_i)} | #{fmt(m_cache_d)} | #{fmt(mr_cache)} |\n"
report << "| Objects allocated (×5000 reads) | #{m_alloc_i} | #{m_alloc_d} | #{mr_alloc} |\n\n"

# 12. Scaling
mint_ins = minting.dig(:scaling, :insert) || []
mint_up  = minting.dig(:scaling, :update) || []
mr_ins   = rails.dig(:scaling, :insert) || []
mr_up    = rails.dig(:scaling, :update) || []

report << "## Scaling: Mass insert\n\n"
report << "| Size | money_attribute (int) | money_attribute (dec) | money-rails | ratio (int) |\n"
report << "|---|---|---|---|---|\n"

mint_ins.each do |row|
  fmt_mi = fmt2(row[:int])
  fmt_md = fmt2(row[:dec])
  mr_row = mr_ins.find { |r| r[:size] == row[:size] }
  fmt_mr = mr_row ? fmt2(mr_row[:mr]) : '—'
  r = row[:int] && mr_row&.dig(:mr) ? ratio(row[:int], mr_row[:mr]) : '—'
  report << "| #{row[:size]} | #{fmt_mi} | #{fmt_md} | #{fmt_mr} | #{r} |\n"
end

report << "\n## Scaling: Bulk update\n\n"
report << "| Size | money_attribute (int) | money_attribute (dec) | money-rails | ratio (int) |\n"
report << "|---|---|---|---|---|\n"

mint_up.each do |row|
  fmt_mi = fmt2(row[:int])
  fmt_md = fmt2(row[:dec])
  mr_row = mr_up.find { |r| r[:size] == row[:size] }
  fmt_mr = mr_row ? fmt2(mr_row[:mr]) : '—'
  r = row[:int] && mr_row&.dig(:mr) ? ratio(row[:int], mr_row[:mr]) : '—'
  report << "| #{row[:size]} | #{fmt_mi} | #{fmt_md} | #{fmt_mr} | #{r} |\n"
end

# Environment
report << "\n## Environment\n\n"
report << "- Ruby: #{RUBY_VERSION}\n"
report << "- Rails: #{Rails::VERSION::STRING}\n"
report << "- SQLite3\n"
report << "- 5000 iterations per test (unless noted)\n"
report << "- Both sides pass a Money object through the attribute setter\n"
report << "- Each side runs in a separate process (no gem conflict)\n"
report << "- Minimal environment (no full Rails app boot)\n"

report_path = File.join(RESULTS_DIR, 'benchmark_report.md')
File.write(report_path, report)
puts "Report written to #{report_path}"
