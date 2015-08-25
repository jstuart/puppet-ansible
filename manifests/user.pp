# = Class : ansible::user
#
# == Summary
#
# Create an ansible user
#
# == Description
#
# This class enable the following features :
#
# - create an ansible user
# - create rsa ssh keys
# - run commands with sudo (optional)
#
# The password is managed by puppet.
# By default, it's not possible to log as the ansible user with a password.
# See shadow and sshd manpages for more information about locked account.
#
# == Parameter
#
# [*sudo*]
# set to 'enable' if you want to authorize ansible user to behave like root
#
# [*password*]
# set to '*NP*' (the default) if you want to a passwordless ansible user
# otherwise set to the desired password
#
# [*uid*]
# set to '' if you want to enable the automatic assignment of UID/GID for the
# ansible user, otherwise set to the desired UID value
#
# == Examples
#
# === Create a ansible user with a non valid password
#
# class { 'ansible::user':
#   sudo => 'enable'
# }
#
# or
#
# include ansible::user
#
# === Create a ansible user with a password
#
# class { 'ansible::user':
#   sudo     => 'enable',
#   password => '<aValidPasswordHash>'
# }
#
class ansible::user(
  $sudo = 'enable',
  $password = '*NP*',
  $uid = '',
) {

  include ansible::params

  if $uid != '' {
    validate_re($ansible::user::uid, '^\d+$', "The value of \$uid must be numeric or an empty string. \$uid = ${ansible::user::uid}")
    $real_uid = $ansible::user::uid
  } else {
    $real_uid = undef
  }

  # Create an 'ansible' user
  user { 'ansible':
    ensure     => present,
    uid        => $real_uid,
    comment    => 'ansible',
    managehome => true,
    shell      => '/bin/bash',
    home       => '/home/ansible',
    password   => $ansible::user::password
  }

  # Create a .ssh directory for the 'ansible' user
  file { '/home/ansible/.ssh' :
    ensure  => directory,
    mode    => '0700',
    owner   => 'ansible',
    group   => 'ansible',
    require => User[ansible],
    notify  => Exec[home_ansible_ssh_keygen]
  }

  # Generate rsa keys for the 'ansible' user
  exec { 'home_ansible_ssh_keygen':
    path    => ['/usr/bin'],
    command => 'ssh-keygen -t rsa -q -f /home/ansible/.ssh/id_rsa -N ""',
    creates => '/home/ansible/.ssh/id_rsa',
    user    => 'ansible',
    require => Package['openssh-server']
  }

  ensure_packages([ 'openssh-server' ])

  # Enable sudo
  if $ansible::user::sudo == 'enable' {

    # Install Sudo if it don't already exist
    ensure_packages([ 'sudo' ])

    # Ansible user can do everything with sudo
    file { '/etc/sudoers.d/ansible' :
      ensure  => file,
      mode    => '0440',
      owner   => 'root',
      group   => 'root',
      content => 'ansible ALL = NOPASSWD : ALL',
      require => Package['sudo']
    }
  }

}
