#!/usr/bin/env ruby

require "run_loop"
require "retriable"
require "luffa"

working_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))

use_xcpretty = ENV["XCPRETTY"] != "0"

xcode = RunLoop::Xcode.new

default_sim_name = RunLoop::Core.default_simulator

default_sim = RunLoop::SimControl.new.simulators.find do |sim|
  sim.instruments_identifier(xcode) == default_sim_name
end

core_sim = RunLoop::CoreSimulator.new(default_sim, nil, {:xcode => xcode})
core_sim.launch_simulator

target_simulator_name = default_sim.name

args =
      [
            'clean',
            'test',
            '-SYMROOT=build',
            '-derivedDataPath build',
            '-project calabash.xcodeproj',
            '-scheme XCTest',
            "-destination 'platform=iOS Simulator,name=#{target_simulator_name},OS=latest'",
            '-sdk iphonesimulator',
            '-configuration Debug',
            use_xcpretty ? '| xcpretty -tc && exit ${PIPESTATUS[0]}' : ''
      ]

Dir.chdir(working_dir) do

  cmd = "xcrun xcodebuild #{args.join(' ')}"

  tries = Luffa::Environment.travis_ci? ? 3 : 1
  interval = 5

  on_retry = Proc.new do |_, try, elapsed_time, next_interval|
    log_fail "XCTest: attempt #{try} failed in '#{elapsed_time}'; will retry in '#{next_interval}'"
    RunLoop::CoreSimulator.quit_simulator
    core_sim.launch_simulator
  end

  class XCTestFailedError < StandardError

  end

  options =
  {
      :intervals => Array.new(tries, interval),
      :on_retry => on_retry,
      :on => [XCTestFailedError]
  }

  Retriable.retriable(options) do
    exit_code = Luffa.unix_command(cmd,
                                   {:pass_msg => 'XCTests passed',
                                    :fail_msg => 'XCTests failed',
                                    :exit_on_nonzero_status => false})
    if Luffa::Environment.travis_ci?
      if exit_code != 0
        log_fail "XCTest exited '#{exit_code}' - did we fail because the Simulator did not launch?"
        raise XCTestFailedError, 'XCTest failed.'
      end
    else
      exit(exit_code)
    end
  end
end

