require "csv"
require "fileutils"

analysis_root = "results/analysis"
comparison_root = "results/comparisons"


fixed_file = File.join(
  analysis_root,
  "margin_00",
  "c17_margin_00_run_001_activity_nwc.csv"
)

unless File.exist?(fixed_file)
  abort "[ERROR] Fixed reference not found: #{fixed_file}"
end

def read_nwc(file)
  data = {}

  CSV.foreach(file, headers: true) do |row|
    signal, cycle, count, first_transition = row.fields

    next if signal.nil? || cycle.nil? || count.nil?

    first_text = first_transition.to_s.strip

    key = [
      signal.strip,
      cycle.to_i
    ]

    data[key] = {
      count: count.to_i,
      first_transition: first_text.empty? ? nil : first_text.to_f
    }
  end

  data
end

reference = read_nwc(fixed_file)

puts "[+] Fixed reference: #{fixed_file}"
puts "[+] Reference values: #{reference.size}"

if reference.empty?
  abort "[ERROR] Fixed reference contains no values"
end


margin_directories = Dir.glob(
  File.join(analysis_root, "margin_*")
).select do |path|
  File.directory?(path) &&
    File.basename(path) != "margin_00"
end.sort

if margin_directories.empty?
  abort "[ERROR] No margin directories found"
end

margin_directories.each do |margin_directory|
  margin_name = File.basename(margin_directory)

  run_files = Dir.glob(
    File.join(
      margin_directory,
      "*_activity_nwc.csv"
    )
  ).sort

  puts
  puts "[+] Comparing #{margin_name}: #{run_files.size} runs"

  if run_files.empty?
    puts "[WARNING] No N(w,c) files found in #{margin_directory}"
    next
  end

  margin_output_directory = File.join(
    comparison_root,
    margin_name
  )

  FileUtils.mkdir_p(margin_output_directory)

  
  count_change_counts = Hash.new(0)
  first_change_counts = Hash.new(0)

  summary_keys = reference.keys.dup

  processed_runs = 0

  run_files.each do |run_file|
    run_name = File.basename(run_file)
                   .delete_suffix("_activity_nwc.csv")

    run_activity = read_nwc(run_file)

    if run_activity.empty?
      puts "[WARNING] Empty N(w,c) file: #{run_file}"
      next
    end

    processed_runs += 1

    all_keys = (
      reference.keys +
      run_activity.keys
    ).uniq

    summary_keys |= all_keys

    differences = []

    all_keys.each do |key|
      signal, cycle = key

      fixed_data = reference.fetch(
        key,
        {
          count: 0,
          first_transition: nil
        }
      )

      run_data = run_activity.fetch(
        key,
        {
          count: 0,
          first_transition: nil
        }
      )

      # Comparaison du nombre de transitions
      fixed_count = fixed_data[:count]
      run_count = run_data[:count]

      count_delta =
        run_count - fixed_count

      count_changed =
        !count_delta.zero?

      # Comparaison du temps de la première transition
      fixed_first =
        fixed_data[:first_transition]

      run_first =
        run_data[:first_transition]

      first_difference =
        if !fixed_first.nil? && !run_first.nil?
          run_first - fixed_first
        else
          nil
        end

      first_changed =
        if fixed_first.nil? && run_first.nil?
          false
        elsif fixed_first.nil? || run_first.nil?
          true 
        else 
          !first_difference.zero?
        end

      next unless count_changed || first_changed

      if count_changed
        count_change_counts[key] += 1
      end

      if first_changed
        first_change_counts[key] += 1
      end

      differences << {
        signal: signal,
        cycle: cycle,
        fixed_count: fixed_count,
        run_count: run_count,
        count_delta: count_delta,
        fixed_first: fixed_first,
        run_first: run_first,
        first_difference: first_difference
      }
    end

    differences.sort_by! do |difference|
      [
        difference[:signal],
        difference[:cycle]
      ]
    end

    output_file = File.join(
      margin_output_directory,
      "#{run_name}_vs_fixed.csv"
    )

    CSV.open(output_file, "w") do |csv|
      csv << [
        "signal",
        "cycle",
        "fixed_count",
        "run_count",
        "count_delta",
        "fixed_first",
        "run_first",
        "first_time_difference"
      ]

      differences.each do |difference|
        csv << [
          difference[:signal],
          difference[:cycle],
          difference[:fixed_count],
          difference[:run_count],
          difference[:count_delta],
          difference[:fixed_first],
          difference[:run_first],
          difference[:first_difference]
        ]
      end
    end

    puts format(
      "    %-40s %6d differences",
      run_name,
      differences.size
    )
  end

  if processed_runs.zero?
    puts "[WARNING] No valid run processed for #{margin_name}"
    next
  end


  summary_file = File.join(
    margin_output_directory,
    "#{margin_name}_summary.csv"
  )

  CSV.open(summary_file, "w") do |csv|
    csv << [
      "signal",
      "cycle",
      "count_changed_runs",
      "first_changed_runs",
      "total_runs",
      "count_change_frequency",
      "first_change_frequency"
    ]

    summary_keys
      .uniq
      .sort_by { |signal, cycle| [signal, cycle] }
      .each do |signal, cycle|

      key = [signal, cycle]

      count_changed_runs =
        count_change_counts[key]

      first_changed_runs =
        first_change_counts[key]

      count_frequency =
        count_changed_runs.to_f / processed_runs

      first_frequency =
        first_changed_runs.to_f / processed_runs

      csv << [
        signal,
        cycle,
        count_changed_runs,
        first_changed_runs,
        processed_runs,
        format("%.4f", count_frequency),
        format("%.4f", first_frequency)
      ]
    end
  end

  puts "[+] Summary saved: #{summary_file}"
end

puts
puts "[+] All comparisons completed."