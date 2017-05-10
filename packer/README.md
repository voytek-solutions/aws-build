# Packer

Packer is used to build AMI (Amazon Machine Images) and Vagrant boxes.




## AMI

Start EC2 box in `mgt` VPC (Virtual Private Cloud) using latest `base_image` AMI,
run `build.yml` playbook against that box, save as AMI.




## Vagrant boxes

The Vagrant box build process is complicated...


### Provisioners Explained

It might be a bit convoluted the first time you look at it, but here is what is
happening during build:

1.	**Setup** - Make sure that the box is setup for vagrant user.

	```
	{
		"type": "shell",
		"execute_command": "echo 'vagrant' | {{.Vars}} sudo -S -E bash '{{.Path}}'",
		"script": "packer/vagrant/scripts/setup.sh"
	},
	```

1.	**Base Image** - Apply base_image role first, so that it looks and works as
	our base_image AMIs.

	```
	{
		"type": "ansible",
		"playbook_file": "./ansible/playbooks/build.yml",
		...
	}
	```

1.	**Build** - Build selected role (like api_kong).

	```
	{
		"type": "ansible",
		"playbook_file": "./ansible/playbooks/build.yml",
		"extra_arguments": [
			"--tags", "build"
			...
		]
		...
	},
	```

1.	**Add Environment Dependencies** - Add environmental dependencies like DBs or
	other services. Each role keeps its environmental dependencies in
	`environment.yml` playbook.

	```
	{
		"type": "ansible",
		"playbook_file": "./ansible/roles/service/{{ user `role` }}/environment.yml",
	},
	```

1.	**Bootstrap Machine** - finally, we will use the same bootstrap method `make
	ansible_provision_local` as we use on AMI bootstrap. This will ensure that this
	vagrant box works the same way as our production boxes.

	```
	{
		"type": "file",
		"source": "ansible/vars/environment.yml",
		"destination": "/bootstrap/environment.yml"
	},
	{
		"type": "shell",
		"execute_command": "echo 'vagrant' | {{.Vars}} sudo -S -E bash '{{.Path}}' '{{ user `role` }}'",
		"script": "packer/vagrant/scripts/configure.sh"
	},
	```

1.	**Cleanup** - Clean up, free up as much space as possible. Also setup vagrant's
	`authorized_keys` using vagrant insecure public key.

	```
	{
		"type": "shell",
		"execute_command": "echo 'vagrant' | {{.Vars}} sudo -S -E bash '{{.Path}}'",
		"script": "packer/vagrant/scripts/cleanup.sh"
	}
	```
