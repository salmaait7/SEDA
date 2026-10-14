require "csv"
require "fileutils"
require "set"

VCD_TICK_FS = 1

def load_signal_names(file)
  File.readlines(file, chomp: true)
      .map { |name| name.strip.downcase }
      .reject(&:empty?)
      .to_set
end

vcd_file = ARGV[0]
output_file = ARGV[1]

unless vcd_file && output_file
  abort("Usage: ruby analyze_vcd.rb INPUT.vcd OUTPUT.csv")
end

vcd_file = File.expand_path(vcd_file)
output_file = File.expand_path(output_file)

unless File.file?(vcd_file)
  abort("[ERROR] VCD file not found: #{vcd_file}")
end

vcd_name = File.basename(vcd_file, ".vcd")

circuit_name =
  ENV["CIRCUIT"] ||
  vcd_name[/\A(.+?)_(?:clean|trojan)_margin_\d+/, 1] ||
  vcd_name[/\A(.+?)_margin_\d+/, 1] ||
  vcd_name.split("_").first

project_root = File.expand_path("..", __dir__)

default_inputs_file = File.join(
  project_root,
  "data",
  "inputs",
  "inputs_#{circuit_name}.txt"
)

default_outputs_file = File.join(
  project_root,
  "data",
  "outputs",
  "outputs_#{circuit_name}.txt"
)

inputs_file = File.expand_path(
  ENV.fetch("INPUTS_FILE", default_inputs_file),
  project_root
)

outputs_only =
  ENV.fetch("OUTPUTS_ONLY", "false").downcase == "true"

outputs_file = File.expand_path(
  ENV.fetch("OUTPUTS_FILE", default_outputs_file),
  project_root
)

nb_cycles = Integer(
  ENV.fetch("NB_CYCLES", "436")
)

step_time_fs = (
  Float(ENV.fetch("STEP_TIME_NS", "20.0")) *
  1_000_000
).round

dut_scope = ENV.fetch("DUT_SCOPE", "dut").downcase

unless File.file?(inputs_file)
  abort("[ERROR] Input list not found: #{inputs_file}")
end

if outputs_only && !File.file?(outputs_file)
  abort("[ERROR] Output list not found: #{outputs_file}")
end

if nb_cycles <= 0
  abort("[ERROR] NB_CYCLES must be greater than zero")
end

if step_time_fs <= 0
  abort("[ERROR] STEP_TIME_NS must be greater than zero")
end

inputs = load_signal_names(inputs_file)

outputs =
  if outputs_only
    load_signal_names(outputs_file)
  else
    Set.new
  end

if outputs_only && outputs.empty?
  abort("[ERROR] Output list is empty: #{outputs_file}")
end


signals = {}


current_values = {}

activity = Hash.new do |hash, key|
  hash[key] = {
    sequence: [],
    times_fs: []
  }
end

scope = []
scope_paths = Set.new
current_time_fs = 0
header_done = false

File.foreach(vcd_file) do |line|
  line = line.strip
  next if line.empty?

  unless header_done
    if line.start_with?("$scope")
      parts = line.split
      scope_name = parts[2].to_s.downcase

      scope << scope_name
      scope_paths << scope.join(".")

    elsif line.start_with?("$upscope")
      scope.pop

    elsif line.start_with?("$var")
      parts = line.split
      next if parts.length < 6

      width = parts[2].to_i
      code = parts[3]
      name = parts[4].downcase

      selected =
        if outputs_only
          outputs.include?(name)
        else
          !inputs.include?(name)
        end

      if scope.last == dut_scope && width == 1 && selected
        signals[code] = name
      end

    elsif line.start_with?("$enddefinitions")
      header_done = true
    end

    next
  end

  if line.start_with?("#")
    raw_time = line[1..].to_i
    current_time_fs = raw_time
    next
  end

  match = line.match(/\A([01xXzZ])(\S+)\z/)
  next unless match

  new_value = match[1].downcase
  code = match[2]
  next unless signals.key?(code)

  old_value = current_values[code]

  if old_value.nil?
    current_values[code] = new_value
    next
  end

  valid_transition =
    old_value != new_value &&
    %w[0 1].include?(old_value) &&
    %w[0 1].include?(new_value)

  if valid_transition
    cycle = current_time_fs.div(step_time_fs)

    if cycle >= 0 && cycle < nb_cycles
      signal = signals.fetch(code)
      data = activity[[signal, cycle]]

      direction = old_value == "0" ? "R" : "F"
      relative_time_fs = current_time_fs % step_time_fs

      data[:sequence] << direction
      data[:times_fs] << relative_time_fs
    end
  end

  current_values[code] = new_value
end

if signals.empty?
  available_scopes = scope_paths.to_a.sort.join(", ")
  selection = outputs_only ? "primary output" : "non-input"

  abort(
    "[ERROR] No #{selection} scalar signal found in DUT scope " \
    "'#{dut_scope}'. Available scopes: #{available_scopes}"
  )
end

if outputs_only
  found_outputs = signals.values.to_set
  missing_outputs = outputs - found_outputs

  unless missing_outputs.empty?
    abort(
      "[ERROR] Outputs missing from the DUT VCD scope: " \
      "#{missing_outputs.to_a.sort.join(', ')}"
    )
  end
end

if activity.empty?
  warn(
    "[WARNING] Signals were found, but no valid 0/1 " \
    "transition was recorded."
  )
end

FileUtils.mkdir_p(File.dirname(output_file))

CSV.open(output_file, "w") do |csv|
  csv << [
    "signal",
    "cycle",
    "activity",
    "sequence",
    "first_transition",
    "transition_times"
  ]

  sorted_keys = activity.keys.sort_by do |signal, cycle|
    [signal, cycle]
  end

  sorted_keys.each do |signal, cycle|
    data = activity.fetch([signal, cycle])

    times_ns = data[:times_fs].map do |time_fs|
      time_fs / 1_000_000.0
    end

    csv << [
      signal,
      cycle,
      data[:sequence].size,
      data[:sequence].join(">"),
      times_ns.first,
      times_ns.join(">")
    ]
  end
end

step_time_ns = step_time_fs / 1_000_000.0

puts
puts "=================================================="
puts "VCD analysis"
puts "=================================================="
puts
puts "VCD file                     : #{vcd_file}"
puts "Circuit                      : #{circuit_name}"
puts "Selection mode               : #{outputs_only ? 'outputs only' : 'all non-input signals'}"
puts "Inputs file                  : #{inputs_file}"
puts "Outputs file                 : #{outputs_file}" if outputs_only
puts "Cycle time                   : #{step_time_fs} fs"
puts "Cycle time                   : #{step_time_ns} ns"
puts "Number of cycles             : #{nb_cycles}"
puts "Signals analysed             : #{signals.size}"
puts "Active (signal, cycle) pairs : #{activity.size}"
puts "Output                       : #{output_file}"