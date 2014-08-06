class ThinkingSphinx::RakeInterface
  def clear
    [
      configuration.indices_location,
      configuration.searchd.binlog_path
    ].each do |path|
      FileUtils.rm_r(path) if File.exists?(path)
    end
  end

  def configure
    puts "Generating configuration to #{configuration.configuration_file}"
    configuration.render_to_file
  end

  def generate
    indices = configuration.indices.select { |index| index.type == 'rt' }
    indices.each do |index|
      ThinkingSphinx::RealTime::Populator.populate index
    end
  end

  def index(reconfigure = true, verbose = true)
    configure if reconfigure
    FileUtils.mkdir_p configuration.tmp_indices_location
    ThinkingSphinx.before_index_hooks.each { |hook| hook.call }
    controller.index :verbose => verbose
  end

  def prepare
    configuration.preload_indices
    configuration.render

    FileUtils.mkdir_p configuration.tmp_indices_location
  end

  def start
    raise RuntimeError, 'searchd is already running' if controller.running?

    FileUtils.mkdir_p configuration.tmp_indices_location
    controller.start

    if controller.running?
      puts "Started searchd successfully (pid: #{controller.pid})."
    else
      puts "Failed to start searchd. Check the log files for more information."
    end
  end

  def stop
    unless controller.running?
      puts 'searchd is not currently running.' and return
    end

    pid = controller.pid
    until controller.stop do
      sleep(0.5)
    end

    puts "Stopped searchd daemon (pid: #{pid})."
  end
  
  def replace
    # replace from tmp_indices_location to indices_location
    FileUtils.mv("#{configuration.tmp_indices_location}/*.*", configuration.indices_location, force: true, verbose: true)
  end

  private

  delegate :controller, :to => :configuration

  def configuration
    ThinkingSphinx::Configuration.instance
  end
end
