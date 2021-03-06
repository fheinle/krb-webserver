# webserver::vhost
#
# Create a new virtual host
#
# @summary This is a wrapper arround 'puppetlabs/apache'
# with krb and ssl from FreeIPA
#
# @example
#   webserver::vhost { 'namevar': }
define webserver::vhost (
    $vhost_name        = $::facts['fqdn'],
    $docroot           = "/var/www/${vhost_name}/html",
    $ssl               = true,
    $kerberos          = true,
    $web_user          = 'www-data',
    $default_vhost     = false,
    $ssl_cert_filename = "/etc/apache2/ssl/${vhost_name}.crt.crt",
    $ssl_key_filename  = "/etc/apache2/ssl/${vhost_name}.crt.key",
    $krb_auth_realm    = undef,
    $krb_5keytab       = undef,
    $krb_servicename   = 'http'
  ) {

  exec { "Create document root ${docroot}":
    creates => $docroot,
    command => "/bin/mkdir -p ${docroot}",
    cwd     => '/var/www/'
  }  -> file { $docroot:
    ensure => directory,
    owner  => $web_user,
    group  => $web_user,
    mode   => '0755',
  }

  apache::vhost { $vhost_name:
    servername    => $vhost_name,
    docroot       => $docroot,
    default_vhost => $default_vhost,
    access_log    => true,
  }

  if $kerberos == true {
    Apache::Vhost[$vhost_name] {
      auth_kerb              => true,
      krb_auth_realms        => [$krb_auth_realm],
      krb_5keytab            => $krb_5keytab,
      krb_servicename        => $krb_servicename,
      krb_local_user_mapping => 'on',
      directories            => [{
        path                 => $docroot,
        auth_name            => 'Kerberos Login',
        auth_type            => 'Kerberos',
        auth_require         => 'pam-account http'
      }]
    }
  }

  if $ssl == true {
    Apache::Vhost <| title == $vhost_name |> {
      port              => '443',
      ssl               => true,
      ssl_protocol      => 'TLSv1.2',
      ssl_cert          => $ssl_cert_filename,
      ssl_key           => $ssl_key_filename,
    }
    apache::vhost { "redirect_${vhost_name}":
      ensure          => present,
      servername      => $vhost_name,
      port            => '80',
      docroot         => $docroot,
      redirect_status => 'permanent',
      redirect_dest   => "https://${vhost_name}/",
    }
  } else {
    Apache::Vhost <| servername == $vhost_name |> {
      port => '80'
    }
  }
}
