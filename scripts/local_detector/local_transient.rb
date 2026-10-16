require "csv"
require "fileutils"
require "json"
require "set"

module LocalTransient

  SCORE_METRICS = %w[
    time_z_gt3_count
  ]

  module_function


  def percentile(values, level)
    return nil if values.empty?

    sorted = values.map(&:to_f).sort

    position = (sorted.length - 1) * level.to_f
    lower = position.floor
    upper = position.ceil

    return sorted[lower] if lower == upper

    sorted[lower] +
      (sorted[upper] - sorted[lower]) *
      (position - lower)
  end

  def median(values)
    percentile(values, 0.50)
  end

  def mad(values)
    center = median(values)
    return nil if center.nil?

    distances = values.map do |value|
      (value.to_f - center).abs
    end

    median(distances)
  end

  def robust_statistics(values, floor:)
    numeric = values.compact.map(&:to_f)
    return nil if numeric.empty?

    center = median(numeric)
    raw_mad = mad(numeric)

    {
      "samples" => numeric.length,
      "median" => center,
      "mad" => raw_mad,
      "scale" => [
        1.4826 * raw_mad,
        floor.to_f
      ].max
    }
  end



  def canonical_sequence(value)
    value.to_s
         .split(">")
         .map(&:strip)
         .reject(&:empty?)
         .map(&:upcase)
         .join(">")
  end

  def parse_times(value)
    value.to_s
         .split(">")
         .map(&:strip)
         .reject(&:empty?)
         .map { |item| Float(item) }
  rescue ArgumentError
    []
  end

  def load_activity(file)
    activity = {}

    CSV.foreach(file, headers: true) do |row|
      signal = row["signal"].to_s.strip.downcase
      next if signal.empty?

      cycle = Integer(row["cycle"], 10)
      sequence = canonical_sequence(row["sequence"])
      times = parse_times(row["transition_times"])

      activity[[signal, cycle]] = {
        sequence: sequence,
        times: times
      }
    end

    activity
  end

  def activity_csv?(file)
    header = File.open(file, &:readline)

    required = %w[
      signal
      cycle
      sequence
      transition_times
    ]

    columns = CSV.parse_line(header).map(&:strip)

    required.all? do |name|
      columns.include?(name)
    end
  rescue EOFError,
         CSV::MalformedCSVError,
         Errno::ENOENT
    false
  end



  def margin_from_path(path)
    match = path.match(/margin_(\d+)/i)

    match && Integer(match[1], 10)
  end

  def run_from_path(path)
    match = path.match(/run_(\d+)/i)

    match ? Integer(match[1], 10) : 0
  end

  def activity_files(root)
    pattern = File.join(
      File.expand_path(root),
      "**",
      "*.csv"
    )

    Dir.glob(pattern)
       .select do |file|
         margin_from_path(file) &&
           activity_csv?(file)
       end
       .sort_by do |file|
         [
           margin_from_path(file),
           run_from_path(file),
           file
         ]
       end
  end

  def group_files_by_margin(files, include_zero: false)
    groups = Hash.new do |hash, key|
      hash[key] = []
    end

    files.each do |file|
      margin = margin_from_path(file)

      next if margin.nil?
      next if margin.zero? && !include_zero

      groups[margin] << File.expand_path(file)
    end

    groups
  end



  def pair_key(signal, cycle)
    "#{signal}\u001f#{cycle}"
  end

  def split_pair_key(key)
    signal, cycle = key.split("\u001f", 2)

    [
      signal,
      Integer(cycle, 10)
    ]
  end


  def select_training_files(
    files,
    train_count:,
    split_seed:,
    margin:
  )
    ordered = files.sort_by do |file|
      [
        run_from_path(file),
        file
      ]
    end

    random = Random.new(
      split_seed.to_i + margin.to_i
    )

    count = [
      train_count.to_i,
      ordered.length
    ].min

    ordered
      .shuffle(random: random)
      .first(count)
      .sort
  end

  # Construction de l’enveloppe temporelle clean
  

  def build_envelope(
    files_by_margin,
    train_count:,
    split_seed:,
    time_floor_ns:,
    min_sequence_samples:
  )
    model = {
      "schema_version" => 1,
      "time_unit" => "ns",
      "time_floor_ns" => time_floor_ns.to_f,
      "min_sequence_samples" =>
        min_sequence_samples.to_i,
      "split_seed" => split_seed.to_i,
      "margins" => {}
    }

    files_by_margin.keys.sort.each do |margin|
      available = files_by_margin.fetch(margin)

      if available.length < train_count.to_i
        warn(
          "[WARNING] margin_#{format('%02d', margin)} " \
          "contains only #{available.length} clean runs, " \
          "while #{train_count} were requested."
        )
      end

      next if available.length < 2

      training_files = select_training_files(
        available,
        train_count: train_count,
        split_seed: split_seed,
        margin: margin
      )

      runs = training_files.map do |file|
        load_activity(file)
      end

     
      pair_keys = runs
                  .flat_map(&:keys)
                  .uniq
                  .sort_by do |signal, cycle|
                    [signal, cycle]
                  end

      pairs = {}

      pair_keys.each do |signal, cycle|
        observations = runs.filter_map do |run|
          run[[signal, cycle]]
        end

 
        observations_by_sequence =
          observations.group_by do |observation|
            observation.fetch(:sequence)
          end

        timing_by_sequence = {}

        observations_by_sequence.each do |sequence, group|
          next if sequence.empty?

          if group.length < min_sequence_samples.to_i
            next
          end

          transition_count = group.map do |observation|
            observation.fetch(:times).length
          end.max.to_i

          transition_statistics = []

          transition_count.times do |transition_index|
            values = group.filter_map do |observation|
              observation
                .fetch(:times)[transition_index]
            end

            if values.length <
               min_sequence_samples.to_i
              next
            end

            transition_statistics[transition_index] =
              robust_statistics(
                values,
                floor: time_floor_ns
              )
          end

          unless transition_statistics.compact.empty?
            timing_by_sequence[sequence] =
              transition_statistics
          end
        end

    
        next if timing_by_sequence.empty?

        pairs[pair_key(signal, cycle)] = {
          "signal" => signal,
          "cycle" => cycle,
          "training_runs" =>
            training_files.length,
          "timing" => timing_by_sequence
        }
      end

      model.fetch("margins")[margin.to_s] = {
        "training_files" => training_files,
        "available_clean_files" =>
          available.length,
        "training_runs" =>
          training_files.length,
        "pairs" => pairs
      }
    end

    model
  end


  def save_model(model, file)
    expanded = File.expand_path(file)

    FileUtils.mkdir_p(
      File.dirname(expanded)
    )

    File.write(
      expanded,
      JSON.pretty_generate(model) + "\n" # Fonction predefined pour formater le JSON avec des indentations et des sauts de ligne
    )
  end

  def load_model(file)
    JSON.parse(
      File.read(file)
    )
  end



  # def write_envelope_summary(model, file)
  #   expanded = File.expand_path(file)

  #   FileUtils.mkdir_p(
  #     File.dirname(expanded)
  #   )

  #   CSV.open(expanded, "w") do |csv|
  #     csv << %w[
  #       margin_percent
  #       signal
  #       cycle
  #       sequence
  #       transition_index
  #       samples
  #       median_ns
  #       mad_ns
  #       scale_ns
  #     ]

  #     margins = model
  #               .fetch("margins")
  #               .keys
  #               .map(&:to_i)
  #               .sort

  #     margins.each do |margin|
  #       margin_model = model
  #                      .fetch("margins")
  #                      .fetch(margin.to_s)

  #       margin_model
  #         .fetch("pairs")
  #         .each_value do |pair|

  #         pair.fetch("timing").each do |
  #           sequence,
  #           statistics
  #         |
  #           statistics.each_with_index do |
  #             stats,
  #             transition_index
  #           |
  #             next unless stats

  #             csv << [
  #               margin,
  #               pair.fetch("signal"),
  #               pair.fetch("cycle"),
  #               sequence,
  #               transition_index,
  #               stats.fetch("samples"),
  #               stats.fetch("median"),
  #               stats.fetch("mad"),
  #               stats.fetch("scale")
  #             ]
  #           end
  #         end
  #       end
  #     end
  #   end
  # end


  # Calcul des scores z d’un run
  def score_file(model, file, variant:, z_threshold:)
    margin = margin_from_path(file)

    margin_model = model.fetch("margins")[margin.to_s]
    return nil unless margin_model

    activity = load_activity(file)
    pairs = margin_model.fetch("pairs")

    local_rows = []
    all_z_scores = []

    activity.each do |(signal, cycle), observation|
      key = pair_key(signal, cycle)
      baseline = pairs[key]

      sequence = observation.fetch(:sequence)

      statistics =
        baseline && baseline.fetch("timing")[sequence]

      observation.fetch(:times).each_with_index do |time_ns, transition_index|
        stats = statistics && statistics[transition_index]

        status =
          if baseline.nil?
            "missing_pair"
          elsif statistics.nil?
            "missing_sequence"
          elsif stats.nil?
            "missing_transition"
          else
            "scored"
          end

        median_ns = nil
        scale_ns = nil
        z = nil
        anomalous = nil

        if status == "scored"
          median_ns = stats.fetch("median").to_f
          scale_ns = stats.fetch("scale").to_f

          z = (time_ns.to_f - median_ns).abs / scale_ns
          anomalous = z > z_threshold.to_f

          all_z_scores << z
        end 
        
        local_rows << {
          signal: signal,
          cycle: cycle,
          sequence: sequence,
          transition_index: transition_index,
          time_ns: time_ns,
          clean_median_ns: median_ns,
          clean_scale_ns: scale_ns,
          z_score: z,
          anomalous: anomalous,
          status: status
        }
      end
    end 
    run_name = File.basename(file, ".csv")

    summary = {
      file: File.expand_path(file),
      run_name: run_name,
      variant: variant,
      margin_percent: margin,

      time_features_total: local_rows.length,
      time_features_scored: all_z_scores.length,
      time_features_uncovered:
        local_rows.length - all_z_scores.length,

      time_z_gt3_count: all_z_scores.count do |z|
        z > z_threshold.to_f
      end
    }

    [summary, local_rows]
  end 




  # Application du score à plusieurs runs
  
  def write_scores(
    model,
    files:,
    variant:,
    run_output:,
    local_output:,
    exclude_training:,
    rare_probability: nil,
    z_threshold:
  )
    training_files =
      model
        .fetch("margins")
        .values
        .flat_map do |margin_model|
          margin_model.fetch("training_files")
        end
        .to_set

    selected = files.reject do |file|
      exclude_training &&
        training_files.include?(
          File.expand_path(file)
        )
    end

    run_headers = %w[
      file
      run_name
      variant
      margin_percent
      time_features_total
      time_features_scored
      time_features_uncovered
      time_z_gt3_count
    ]

    local_headers = %w[
      file
      run_name
      variant
      margin_percent
      signal
      cycle
      sequence
      transition_index
      time_ns
      clean_median_ns
      clean_scale_ns
      z_score
      anomalous
      status
    ]

    FileUtils.mkdir_p(
      File.dirname(
        File.expand_path(run_output)
      )
    )

    FileUtils.mkdir_p(
      File.dirname(
        File.expand_path(local_output)
      )
    )

    scored_runs = 0

    CSV.open(run_output, "w") do |run_csv|
      CSV.open(local_output, "w") do |local_csv|
        run_csv << run_headers
        local_csv << local_headers

        selected.each do |file|
          result = score_file(
            model,
            file,
            variant: variant,
            z_threshold: z_threshold
          )

          next unless result

          summary, local_rows = result

          run_csv << run_headers.map do |header|
            summary.fetch(header.to_sym)
          end

          local_rows.each do |row|
            prefix = {
              file: summary.fetch(:file),
              run_name:
                summary.fetch(:run_name),
              variant:
                summary.fetch(:variant),
              margin_percent:
                summary.fetch(
                  :margin_percent
                )
            }

            complete = prefix.merge(row)

            local_csv << local_headers.map do |header|
              complete.fetch(header.to_sym)
            end
          end

          scored_runs += 1
        end
      end
    end

    scored_runs
  end

 
  # Lecture des scores et calcul de l’AUC
  
  def read_run_scores(file)
    CSV.foreach(file, headers: true).map do |row|
      row.to_h
    end
  end

  def auc(clean_scores, trojan_scores)
    return nil if clean_scores.empty? || trojan_scores.empty?

    points = 0.0

    trojan_scores.each do |trojan|
      clean_scores.each do |clean|
        if trojan.to_f > clean.to_f
          points += 1
        elsif trojan.to_f == clean.to_f
          points += 0.5
        end
        # si le score Trojan est inférieur aucun point ajouté
      end
    end

    comparisons = clean_scores.length * trojan_scores.length

    points / comparisons
  end
end