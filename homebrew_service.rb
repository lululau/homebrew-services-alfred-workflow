require_relative 'alfred'

ICON = {
  'started' => 'started.png',
  'stopped' => 'stopped.png'
}

def list(query=nil)
  cmd_out = `/usr/local/bin/brew services list`
  services = cmd_out.lines[1..-1].map { |l| l.chomp.scan(/\S+/)[0,2] }.select { |name, status| query.nil? || name.include?(query) }
  item_list = ItemList.new
  item_list.items = services.map { |name, status|
    item = Item.new
    item.title = name
    item.subtitle = "Status: #{status}"
    item.icon[:text] = ICON[status]
    item.attributes = {
      arg: "#{name}:#{status}"
    }
    item
  }
  item_list.to_xml
end


def start(service_name)
  system "/usr/local/bin/brew services start #{service_name}"
end

def stop(service_name)
  system "/usr/local/bin/brew services stop #{service_name}"
end

if ARGV[0] == 'list'
  print list(ARGV[1])
elsif ARGV[0]
  service_name, status = ARGV[0].split(':')
  if status == 'started'
    stop(service_name)
  elsif status == 'stopped'
    start(service_name)
  end
end
