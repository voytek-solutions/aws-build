# Install plugins

required_plugins = %w( vagrant-hosts-provisioner )
required_plugins.each do |plugin|
	exec "vagrant plugin install #{plugin};vagrant #{ARGV.join(" ")}" unless Vagrant.has_plugin? plugin || ARGV[0] == 'plugin'
end
