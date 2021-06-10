# @summary
#   Installs `mod_ssl`.
# 
# @param ssl_compression
#   Enable compression on the SSL level.
#
# @param ssl_cryptodevice
#   Enable use of a cryptographic hardware accelerator.
#
# @param ssl_options
#   Configure various SSL engine run-time options.
#
# @param ssl_openssl_conf_cmd
#   Configure OpenSSL parameters through its SSL_CONF API.
#
# @param ssl_cert
#   Path to server PEM-encoded X.509 certificate data file.
#
# @param ssl_key
#   Path to server PEM-encoded private key file
#
# @param ssl_ca
#   File of concatenated PEM-encoded CA Certificates for Client Auth.
#
# @param ssl_cipher
#   Cipher Suite available for negotiation in SSL handshake.
#
# @param ssl_honorcipherorder
#   Option to prefer the server's cipher preference order.
#
# @param ssl_protocol
#   Configure usable SSL/TLS protocol versions.
#   Default based on the OS:
#   - RedHat 8: [ 'all' ].
#   - Other Platforms: [ 'all', '-SSLv2', '-SSLv3' ].
#
# @param ssl_proxy_protocol
#   Configure usable SSL protocol flavors for proxy usage.
#
# @param ssl_pass_phrase_dialog
#   Type of pass phrase dialog for encrypted private keys.
#
# @param ssl_random_seed_bytes
#   Pseudo Random Number Generator (PRNG) seeding source.
#
# @param ssl_sessioncache
#   Configures the storage type of the global/inter-process SSL Session Cache
#
# @param ssl_sessioncachetimeout
#   Number of seconds before an SSL session expires in the Session Cache.
#
# @param ssl_stapling
#   Enable stapling of OCSP responses in the TLS handshake.
#
# @param ssl_stapling_return_errors
#   Pass stapling related OCSP errors on to client.
#
# @param ssl_mutex
#   Configures mutex mechanism and lock file directory for all or specified mutexes.
#   Default based on the OS and/or Apache version:
#   - RedHat/FreeBSD/Suse/Gentoo: 'default'.
#   - Debian/Ubuntu + Apache >= 2.4: 'default'.
#   - Debian/Ubuntu + Apache < 2.4: 'file:${APACHE_RUN_DIR}/ssl_mutex'.
#
# @param ssl_reload_on_change
#   Enable reloading of apache if the content of ssl files have changed.
#
# @param apache_version
#   Used to verify that the Apache version you have requested is compatible with the module.
#
# @param package_name
#   Name of ssl package to install.
#
# On most operating systems, the ssl.conf is placed in the module configuration directory. On Red Hat based operating systems, this
# file is placed in /etc/httpd/conf.d, the same location in which the RPM stores the configuration.
#
# To use SSL with a virtual host, you must either set the default_ssl_vhost parameter in ::apache to true or the ssl parameter in 
# apache::vhost to true.
#
# @see https://httpd.apache.org/docs/current/mod/mod_ssl.html for additional documentation.
#
class apache::mod::ssl (
  Boolean $ssl_compression                                  = false,
  Optional[Boolean] $ssl_sessiontickets                     = undef,
  $ssl_cryptodevice                                         = 'builtin',
  $ssl_options                                              = ['StdEnvVars'],
  $ssl_openssl_conf_cmd                                     = undef,
  Optional[String] $ssl_cert                                = undef,
  Optional[String] $ssl_key                                 = undef,
  $ssl_ca                                                   = undef,
  $ssl_cipher                                               = 'HIGH:MEDIUM:!aNULL:!MD5:!RC4:!3DES',
  Variant[Boolean, Enum['on', 'off']] $ssl_honorcipherorder = true,
  $ssl_protocol                                             = $apache::params::ssl_protocol,
  Array $ssl_proxy_protocol                                 = [],
  $ssl_pass_phrase_dialog                                   = 'builtin',
  $ssl_random_seed_bytes                                    = '512',
  String $ssl_sessioncache                                  = $apache::params::ssl_sessioncache,
  $ssl_sessioncachetimeout                                  = '300',
  Boolean $ssl_stapling                                     = false,
  Optional[String] $stapling_cache                          = undef,
  Optional[Boolean] $ssl_stapling_return_errors             = undef,
  $ssl_mutex                                                = undef,
  Boolean $ssl_reload_on_change                             = false,
  $apache_version                                           = undef,
  $package_name                                             = undef,
) inherits ::apache::params {
  include apache
  include apache::mod::mime
  $_apache_version = pick($apache_version, $apache::apache_version)
  if $ssl_mutex {
    $_ssl_mutex = $ssl_mutex
  } else {
    case $::osfamily {
      'debian': {
        if versioncmp($_apache_version, '2.4') >= 0 {
          $_ssl_mutex = 'default'
        } else {
          $_ssl_mutex = "file:\${APACHE_RUN_DIR}/ssl_mutex"
        }
      }
      'redhat': {
        $_ssl_mutex = 'default'
      }
      'freebsd': {
        $_ssl_mutex = 'default'
      }
      'gentoo': {
        $_ssl_mutex = 'default'
      }
      'Suse': {
        $_ssl_mutex = 'default'
      }
      default: {
        fail("Unsupported osfamily ${::osfamily}, please explicitly pass in \$ssl_mutex")
      }
    }
  }

  if $ssl_honorcipherorder =~ Boolean {
    $_ssl_honorcipherorder = $ssl_honorcipherorder
  } else {
    $_ssl_honorcipherorder = $ssl_honorcipherorder ? {
      'on'    => true,
      'off'   => false,
      default => true,
    }
  }

  if $stapling_cache =~ Undef {
    $_stapling_cache = $::osfamily ? {
      'debian'  => "\${APACHE_RUN_DIR}/ocsp(32768)",
      'redhat'  => '/run/httpd/ssl_stapling(32768)',
      'freebsd' => '/var/run/ssl_stapling(32768)',
      'gentoo'  => '/var/run/ssl_stapling(32768)',
      'Suse'    => '/var/lib/apache2/ssl_stapling(32768)',
    }
  } else {
    $_stapling_cache = $stapling_cache
  }

  if $::osfamily == 'Suse' {
    if defined(Class['::apache::mod::worker']) {
      $suse_path = '/usr/lib64/apache2-worker'
    } else {
      $suse_path = '/usr/lib64/apache2-prefork'
    }
    ::apache::mod { 'ssl':
      package  => $package_name,
      lib_path => $suse_path,
    }
  } else {
    ::apache::mod { 'ssl':
      package => $package_name,
    }
  }

  if versioncmp($_apache_version, '2.4') >= 0 {
    include apache::mod::socache_shmcb
  }

  file { $apache::params::puppet_ssl_dir:
    ensure  => directory,
    purge   => true,
    recurse => true,
  }
  file { 'README.txt':
    path    => "${apache::params::puppet_ssl_dir}/README.txt",
    content => 'This directory contains puppet managed copies of ssl files, so it can track changes and reload apache on changes.',
    seltype => 'etc_t',
  }
  if $ssl_reload_on_change {
    if $ssl_cert {
      $_ssl_cert_copy = regsubst($ssl_cert, '/', '_', 'G')
      file { $_ssl_cert_copy:
        path   => "${apache::params::puppet_ssl_dir}/${_ssl_cert_copy}",
        source => "file://${ssl_cert}",
        mode   => '0640',
        notify => Class['apache::service'],
      }
    }
    if $ssl_key {
      $_ssl_key_copy = regsubst($ssl_key, '/', '_', 'G')
      file { $_ssl_key_copy:
        path   => "${apache::params::puppet_ssl_dir}/${_ssl_key_copy}",
        source => "file://${ssl_key}",
        mode   => '0640',
        notify => Class['apache::service'],
      }
    }
    if $ssl_ca {
      $_ssl_ca_copy = regsubst($ssl_ca, '/', '_', 'G')
      file { $_ssl_ca_copy:
        path   => "${apache::params::puppet_ssl_dir}/${_ssl_ca_copy}",
        source => "file://${ssl_ca}",
        mode   => '0640',
        notify => Class['apache::service'],
      }
    }
  }

  # Template uses
  #
  # $ssl_compression
  # $ssl_sessiontickets
  # $ssl_cryptodevice
  # $ssl_ca
  # $ssl_cipher
  # $ssl_honorcipherorder
  # $ssl_options
  # $ssl_openssl_conf_cmd
  # $ssl_sessioncache
  # $_stapling_cache
  # $ssl_mutex
  # $ssl_random_seed_bytes
  # $ssl_sessioncachetimeout
  # $_apache_version
  file { 'ssl.conf':
    ensure  => file,
    path    => $apache::_ssl_file,
    mode    => $apache::file_mode,
    content => template('apache/mod/ssl.conf.erb'),
    require => Exec["mkdir ${apache::mod_dir}"],
    before  => File[$apache::mod_dir],
    notify  => Class['apache::service'],
  }
}
