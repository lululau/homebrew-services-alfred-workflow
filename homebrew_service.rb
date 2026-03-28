require_relative 'alfred'

ICON = {
  'started' => 'started.png',
  'stopped' => 'stopped.png'
}

HOMEBREW_PREFIXES = ["/opt/homebrew", "/usr/local"].select { |p| File.exist?(p) }

def homebrew_plist_files
  HOMEBREW_PREFIXES.flat_map { |prefix| Dir.glob("#{prefix}/opt/*/homebrew*.plist") }
end

def running_services
  @running_services ||= `launchctl list`.lines
    .map { |line| line.chomp.split("\t") }
    .select { |cols| cols[0] != '-' && cols.size >= 3 }
    .map { |cols| cols[2] }
end

def list(query = nil)
  # Group by basename to deduplicate, take last (handles multiple prefixes)
  services = homebrew_plist_files
    .group_by { |f| File.basename(f, '.plist') }
    .values
    .map { |files| File.basename(files.last, '.plist') }
    .select { |name| query.nil? || name.include?(query) }
    .sort_by { |name| [running_services.include?(name) ? 0 : 1, name] }

  item_list = ItemList.new
  item_list.items = services.map { |name|
    status = running_services.include?(name) ? 'started' : 'stopped'
    item = Item.new
    item.title = name.sub('homebrew.mxcl.', '')
    item.subtitle = "Status: #{status.capitalize}"
    item.icon[:text] = ICON[status]
    item.attributes = { arg: "#{item.title}:#{status}" }
    item
  }
  item_list.to_xml
end

if ARGV[0] == 'list'
  print list(ARGV[1])
elsif ARGV.size >= 2
  service_name, status = ARGV[1].split(':')
  cmd = case ARGV[0]
        when 'run'
          status == 'started' ? 'stop --keep' : 'run'
        when 'auto'
          status == 'started' ? 'stop' : 'start'
        end
  system "brew services #{cmd} #{service_name}"
end
