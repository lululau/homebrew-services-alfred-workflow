require_relative 'alfred'

ICON = {
  'started' => 'started.png',
  'stopped' => 'stopped.png'
}

class Service
  attr_accessor :plist, :name, :status, :full_name

  def initialize(plist)
    @plist = plist
  end

  def name
    @name ||= @plist.gsub(/.*homebrew\.mxcl\./, '').gsub(/\.plist/, '')
  end

  def full_name
    @full_name ||= File.basename(@plist, '.plist')
  end

  def status
    return @status if @status
    status_code = Service.launchctl_output.find { |_, code, name| name == full_name}
    @status = (status_code && status_code[1] == '0' ? 'started' : 'stopped')
  end

  def load
    system "launchctl load #{plist}"
  end

  def unload
    system "launchctl unload #{plist}"
  end

  def copy_to_launch_agent_dir
    system "cp -f #{plist} ~/Library/LaunchAgents/"
  end

  def remove_from_launch_agent_dir
    system "rm -f ~/Library/LaunchAgents/#{File.basename(plist)}"
  end

  class << self
    def all
      find_launchd_plist_files.map { |plist| new(plist) }
    end

    def find_by_name(name)
      all.find { |e| e.name == name }
    end

    def load_by_name(name, auto = false)
      svc = find_by_name(name)
      svc.load
      svc.copy_to_launch_agent_dir if auto
    end

    def unload_by_name(name, auto = false)
      svc = find_by_name(name)
      svc.remove_from_launch_agent_dir if auto
      svc.unload
    end

    def homebrew_prefix
      unless @homebrew_prefix
        if File.exists?("/opt/homebrew")
          @homebrew_prefix = "/opt/homebrew"
        else
          @homebrew_prefix = "/usr/local"
        end
      end
      @homebrew_prefix
    end

    def find_launchd_plist_files
      Dir.glob("#{homebrew_prefix}/opt/*/homebrew*.plist")
    end

    def launchctl_output
      @launchctl_output ||= `launchctl list`.lines.map { |e| e.chomp.split("\t") }
    end
  end
end

def list(query=nil)
  services = Service.all
    .select { |svc| query.nil? || svc.name.include?(query) }
    .sort_by { |svc| [svc.status, svc.name] }
  item_list = ItemList.new
  item_list.items = services.map { |svc|
    item = Item.new
    item.title = svc.name
    item.subtitle = "Status: #{svc.status.capitalize}"
    item.icon[:text] = ICON[svc.status]
    item.attributes = {
      arg: "#{svc.name}:#{svc.status}"
    }
    item
  }
  item_list.to_xml
end


if ARGV[0] == 'list'
  print list(ARGV[1])
elsif ARGV.size >= 2
  service_name, status = ARGV[1].split(':')
  if status == 'started'
    Service.unload_by_name(service_name, ARGV[0] == 'auto')
  elsif status == 'stopped'
    Service.load_by_name(service_name, ARGV[0] == 'auto')
  end
end
