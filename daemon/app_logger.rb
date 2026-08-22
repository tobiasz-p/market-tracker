# frozen_string_literal: true

require "logger"

# Subclass of standard Ruby Logger configured with market-tracker progname and custom formatter.
class AppLogger < Logger
  PROGNAME = "market-tracker"

  def initialize(device = $stderr)
    super(device, progname: PROGNAME)
    self.formatter = proc { |_severity, _time, progname, message| "[#{progname}] #{message}\n" }
  end
end
