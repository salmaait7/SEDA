require_relative "../lib/seda"

files = {
  original_fixed_delay: "activity/activity_original_circuit_fixed_delay.csv",
  original_fixed_epsilon: "activity/activity_original_circuit_fixed_epsilon.csv",
  original_variable_epsilon: "activity/activity_original_circuit_variable_epsilon.csv",

  altered_fixed_delay: "activity/activity_altered_circuit_fixed_delay.csv",
  altered_fixed_epsilon: "activity/activity_altered_circuit_fixed_epsilon.csv",
  altered_variable_epsilon: "activity/activity_altered_circuit_variable_epsilon.csv"
}

results = {}

files.each do |case_name, file|
  puts
  puts "Case: #{case_name}"
  puts "======================="

  results[case_name] = Seda::ActivityAnalyzer.analyze_file(file)
end


comparisons = [
  [:original_fixed_delay, :original_fixed_epsilon],
  [:original_fixed_delay, :original_variable_epsilon],

  [:original_variable_epsilon, :altered_fixed_epsilon],
  [:altered_fixed_delay, :original_variable_epsilon],
  [:altered_variable_epsilon, :original_variable_epsilon]
]

comparisons.each do |case_a, case_b|
  Seda::ActivityAnalyzer.compare(
    results,
    case_a,
    case_b
  
  )
end