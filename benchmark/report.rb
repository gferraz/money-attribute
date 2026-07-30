# frozen_string_literal: true

# Generate a consolidated markdown benchmark report.
# Run: bundle exec ruby benchmark/report.rb

require 'open3'
require 'fileutils'
require 'date'
require 'bundler/setup'
require 'rails'

RESULTS_DIR  = File.expand_path('../tmp', __dir__)
FileUtils.mkdir_p(RESULTS_DIR)

SIDES = {
  'minting'    => { script: 'minting.rb',    label: 'money_attribute' },
  'plain'      => { script: 'plain.rb',      label: 'plain Rails' },
  'money_rails' => { script: 'money_rails.rb', label: 'money-rails' }
}.freeze

def run_side(side)
  info = SIDES.fetch(side)
  script = File.expand_path(info[:script], __dir__)
  out_file = File.join(RESULTS_DIR, "bench_#{side}.out")
  env = { 'RAILS_ENV' => 'test' }
  env['BUNDLE_GEMFILE'] = 'Gemfile.benchmark' if side == 'money_rails'
  cmd = %w[bundle exec ruby] + [script]

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

# Parse scaling lines (minting/plain sides: 4 values + label):
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
  /Read (Money attribute|raw column)/ => :read,
  /Query by raw columns/ => :query_raw,
  /Query by Money object/ => :query_money_object,
  /SQL generation/ => :sql_gen,
  /multi-record/ => :multi_record,
  /Arithmetic/ => :arithmetic,
  /Query helpers/ => :query_helpers,
  /Repeated access|caching/ => :caching,
  /Scaling/ => :scaling,
  /Format benchmark/ => :format
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

INT   = 'money_attribute (integer column)'
DEC   = 'money_attribute (decimal column)'
PLAIN = 'plain Rails (integer column)'
PLAIN_DEC = 'plain Rails (decimal column)'
MR    = 'money-rails (integer cents)'
MRQ   = 'money-rails (integer cents, currency)'

def bm_val(data, section, label)
  data.dig(:bm, section, label, :real)
end

def section_table(data, section, title, dec_label: DEC, mr_label: MR, show_plain: true)
  m_i = bm_val(data[:mint], section, INT)
  m_d = dec_label ? bm_val(data[:mint], section, dec_label) : nil
  p   = show_plain ? bm_val(data[:plain], section, PLAIN) : nil
  r   = mr_label ? bm_val(data[:mr], section, mr_label) : nil

  report = +''
  report << "## #{title}\n\n"

  if show_plain
    ma_vs_plain = m_i && p && p.positive? ? format('%.1f×', m_i / p) : '—'
    report << "| money_attribute (int) | money_attribute (dec) | money-rails | plain Rails | ma / plain |\n"
    report << "|---|---|---|---|---|\n"
    report << "| #{fmt(m_i)} | #{fmt(m_d)} | #{fmt(r)} | #{fmt(p)} | #{ma_vs_plain} |\n"
  else
    comp = ratio(m_i, r)
    report << "| Variant | money_attribute (int) | money_attribute (dec) | money-rails | Comparison |\n"
    report << "|---|---|---|---|---|\n"
    report << "| integer column | #{fmt(m_i)} | #{fmt(m_d)} | #{fmt(r)} | #{comp || '—'} |\n"
  end
  report << "\n"
  report
end

puts 'Running money_attribute benchmark...'
minting_out = run_side('minting')
minting = parse_output(minting_out)

puts 'Running plain Rails benchmark...'
plain_out = run_side('plain')
plain = parse_output(plain_out)

puts 'Running money-rails benchmark...'
rails_out = run_side('money_rails')
rails = parse_output(rails_out)

# ── Generate report ────────────────────────────────────────────

puts "\nGenerating report..."

report = +''
report << "# Benchmark Report: money_attribute vs plain Rails vs money-rails\n\n"
report << "Run at: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}\n"
report << "Ruby #{RUBY_VERSION}, Rails #{Rails::VERSION::STRING}\n\n"

data = { mint: minting, plain:, mr: rails }

# 1. Instantiation
report << section_table(data, :instantiation, 'Instantiation')

# 2. Create + save
report << section_table(data, :create_save, 'Create + save')

# 3. Update existing
report << section_table(data, :update_existing, 'Update existing record')

# 4. Setter only
report << section_table(data, :setter_only, 'Setter only (no DB write)')

# 5. Read cached
report << section_table(data, :read, 'Read from cached record')

# 6. Query raw columns
report << section_table(data, :query_raw, 'Query by raw columns', mr_label: MRQ)

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
report << section_table(data, :sql_gen, 'SQL generation (.to_sql)', mr_label: MRQ)

# 9. Multi-record query
report << section_table(data, :multi_record, 'Multi-record query (100 records × 1000 iters)')

# 10. Arithmetic
m_arith = bm_val(minting, :arithmetic, INT)
report << "## Arithmetic\n\n"
report << "| Variant | money_attribute |\n"
report << "|---|---|\n"
report << "| integer column | #{fmt(m_arith)} |\n\n"

# 11. Query helpers
qh_m = minting.dig(:bm, :query_helpers) || {}
qh_p = plain.dig(:bm, :query_helpers) || {}

if qh_m.any? || qh_p.any?
  report << "## Query helpers\n\n"
  report << "| Benchmark | money_attribute | plain Rails | ma / plain |\n"
  report << "|---|---|---|---|\n"
  all_labels = (qh_m.keys + qh_p.keys).uniq
  all_labels.each do |label|
    m_val = qh_m.dig(label, :real)
    p_val = qh_p.dig(label, :real)
    comp = m_val && p_val && p_val.positive? ? format('%.1f×', m_val / p_val) : '—'
    report << "| #{label} | #{fmt(m_val)} | #{fmt(p_val)} | #{comp} |\n"
  end
  report << "\n"
end

# 12. Caching
m_int_same = minting.dig(:identity, 'money_attribute composite int')
m_dec_same = minting.dig(:identity, 'money_attribute composite dec')
p_int_same = plain.dig(:identity, 'plain Rails (int)')
p_dec_same = plain.dig(:identity, 'plain Rails (dec)')
mr_same    = rails.dig(:identity, 'money-rails composite int')

m_cache_i  = bm_val(minting, :caching, INT)
m_cache_d  = bm_val(minting, :caching, DEC)
p_cache_i  = bm_val(plain, :caching, PLAIN)
p_cache_d  = bm_val(plain, :caching, PLAIN_DEC)
mr_cache   = bm_val(rails, :caching, MR)

m_alloc_i  = minting.dig(:alloc, 'money_attribute (integer column)')
m_alloc_d  = minting.dig(:alloc, 'money_attribute (decimal column)')
p_alloc_i  = plain.dig(:alloc, 'plain Rails (integer column)')
p_alloc_d  = plain.dig(:alloc, 'plain Rails (decimal column)')
mr_alloc   = rails.dig(:alloc, 'money-rails (integer cents)')

report << "## Caching\n\n"
report << "| Property | money_attribute (int) | money_attribute (dec) | money-rails | plain Rails (int) | plain Rails (dec) |\n"
report << "|---|---|---|---|---|---|\n"
report << "| Same object on repeated read? | #{m_int_same} | #{m_dec_same} | #{mr_same} | #{p_int_same} | #{p_dec_same} |\n"
report << "| Repeated read ×5000 | #{fmt(m_cache_i)} | #{fmt(m_cache_d)} | #{fmt(mr_cache)} | #{fmt(p_cache_i)} | #{fmt(p_cache_d)} |\n"
report << "| Objects allocated (×5000 reads) | #{m_alloc_i} | #{m_alloc_d} | #{mr_alloc} | #{p_alloc_i} | #{p_alloc_d} |\n\n"

# 13. Format benchmark (Money.format vs number_to_currency)
FORMAT_LABELS = {
  '(small default)' => %w[small default],
  '(large default)' => %w[large default],
  '(huge default)'  => %w[huge default],
  '(no symbol)'     => %w[large no symbol],
  '(comma dec)'     => %w[large comma dec],
  '(no delim)'      => %w[large no delim],
  '(wide symbol)'   => %w[large wide symbol]
}.freeze

fmt_data = minting.dig(:bm, :format) || {}

if fmt_data.any?
  report << "## Format benchmark: Money.format vs number_to_currency\n\n"
  report << "10 000 iterations per variant.\n\n"
  report << "| Variant | Money.format | number_to_currency | ratio |\n"
  report << "|---|---|---|---|\n"

  FORMAT_LABELS.each_key do |variant|
    mf_key = "Money.format #{variant}"
    ntc_key = "number_to_currency #{variant}"
    mf_val = bm_val(minting, :format, mf_key)
    ntc_val = bm_val(minting, :format, ntc_key)
    comp = ratio(mf_val, ntc_val) || '—'
    report << "| #{variant.sub(/^\(/, '').sub(/\)$/, '')} | #{fmt(mf_val)} | #{fmt(ntc_val)} | #{comp} |\n"
  end

  report << "\n"
end

# 14. Scaling
mint_ins = minting.dig(:scaling, :insert) || []
mint_up  = minting.dig(:scaling, :update) || []
plain_ins = plain.dig(:scaling, :insert) || []
plain_up  = plain.dig(:scaling, :update) || []
mr_ins   = rails.dig(:scaling, :insert) || []
mr_up    = rails.dig(:scaling, :update) || []

report << "## Scaling: Mass insert\n\n"
report << "| Size | money_attribute (int) | money_attribute (dec) | money-rails | plain Rails (int) | ma / plain |\n"
report << "|---|---|---|---|---|---|\n"

mint_ins.each do |row|
  fmt_mi = fmt2(row[:int])
  fmt_md = fmt2(row[:dec])
  pr_row = plain_ins.find { |r| r[:size] == row[:size] }
  fmt_pr = pr_row ? fmt2(pr_row[:int]) : '—'
  mr_row = mr_ins.find { |r| r[:size] == row[:size] }
  fmt_mr = mr_row ? fmt2(mr_row[:mr]) : '—'
  ma_vs_plain = row[:int] && pr_row&.dig(:int) && pr_row[:int].positive? ? format('%.1f×', row[:int] / pr_row[:int]) : '—'
  report << "| #{row[:size]} | #{fmt_mi} | #{fmt_md} | #{fmt_mr} | #{fmt_pr} | #{ma_vs_plain} |\n"
end

report << "\n## Scaling: Bulk update\n\n"
report << "| Size | money_attribute (int) | money_attribute (dec) | money-rails | plain Rails (int) | ma / plain |\n"
report << "|---|---|---|---|---|---|\n"

mint_up.each do |row|
  fmt_mi = fmt2(row[:int])
  fmt_md = fmt2(row[:dec])
  pr_row = plain_up.find { |r| r[:size] == row[:size] }
  fmt_pr = pr_row ? fmt2(pr_row[:int]) : '—'
  mr_row = mr_up.find { |r| r[:size] == row[:size] }
  fmt_mr = mr_row ? fmt2(mr_row[:mr]) : '—'
  ma_vs_plain = row[:int] && pr_row&.dig(:int) && pr_row[:int].positive? ? format('%.1f×', row[:int] / pr_row[:int]) : '—'
  report << "| #{row[:size]} | #{fmt_mi} | #{fmt_md} | #{fmt_mr} | #{fmt_pr} | #{ma_vs_plain} |\n"
end

# Environment
report << "\n## Environment\n\n"
report << "- Ruby: #{RUBY_VERSION}\n"
report << "- Rails: #{Rails::VERSION::STRING}\n"
report << "- SQLite3\n"
report << "- 5000 iterations per test (unless noted)\n"
report << "- money_attribute and money-rails pass a Money object through the attribute setter\n"
report << "- plain Rails passes raw column values (subunits for int, BigDecimal for dec)\n"
report << "- Each side runs in a separate process (no gem conflict)\n"
report << "- Minimal environment (no full Rails app boot)\n"

report_name = "benchmark-report-#{Date.today}.md"
report_path = File.join(RESULTS_DIR, report_name)
File.write(report_path, report)
puts "Report written to #{report_path}"
