# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

# include some helpers
rootDir = File.expand_path('.')
require "#{rootDir}/vagrant/config.rb"
require "#{rootDir}/vagrant/shame.rb"
require "#{rootDir}/vagrant/plugins.rb"

vm_name = ENV['ROLE']

Vagrant.configure(VAGRANTFILE_API_VERSION) do |m_config|

	cfg = getConfig()

	m_config.vm.define vm_name do |config|
		config.vm.box = "ubuntu/xenial64"
		config.vm.box_check_update = false

		config.ssh.forward_agent = true

		config.vm.network :private_network,
			ip: cfg[vm_name]['priv_ip']

		config.vm.provision :hostsupdate, run: 'always' do |host|
			host.hostname = vm_name
			host.manage_guest = true
			host.manage_host = true
			host.aliases = cfg[vm_name]['hosts']
		end

		config.vm.provider :virtualbox do |vb|
			vb.customize ["modifyvm", :id, "--memory", cfg['vm']['memory']]
			vb.customize ["modifyvm", :id, "--cpus", cfg['vm']['cores']]
			vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
			vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
		end

		config.vm.provision "shell" do |shell|
			shell.inline = "apt-get update && apt-get install python2.7 -y && ln -fs /usr/bin/python2.7 /usr/bin/python"
		end

		build_steps = getBuildSteps(ENV['MODE'])
		build_steps.each do | run |
			config.vm.provision "ansible" do |ansible|
				ansible.playbook = "#{rootDir}/ansible/roles/#{vm_name}/#{run['play']}.yml"
				ansible.extra_vars = {
					'build_local' => true,
					'hosts' => vm_name,
					'pwd' => rootDir
				}.merge(cfg)
				ansible.tags = run['tags']
				ansible.verbose = "#{ENV['VERBOSE']}" if ENV['VERBOSE']
			end
		end
	end
end

def configSetup(cfg)
	getInput("How many cores?", cfg['vm'], 'cores', 1)
	getInput("How much memory?", cfg['vm'], 'memory', 512)
end

# used by ./vagrant/config.rb to get config file name
# This is relative to the folder from where you run `vagrant up`
def getConfigFolder()
	File.expand_path('.') + "/ansible/roles/#{ENV['ROLE']}"
end
