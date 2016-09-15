$network_node_int_iface = $ipaddress_eth2
$network_node_ext_iface = $ipaddress_eth1
$network_node_mgt_iface = $ipaddress_eth0
$compute_node_mgt_iface = $ipaddress_eth0
$compute_node_int_iface = $ipaddress_br_int

$db_host        = '192.168.56.3'
$db_root_pw     = 'openstack'

$api_address    = '192.168.56.3'
$ext_address    = '192.168.56.3'
$rabbit_address = '192.168.56.3'
$rabbit_user    = 'guest'
$rabbit_pass    = 'rabbitpass'
$rabbit_port    = '5672'

$openstack_admin_pass = 'openstack'
$openstack_admin_mail = 'openstack@diegolima.org'
$openstack_region     = 'shot01'

$keystone_admin_token = 'abcd123'
$keystone_db_user = 'keystone'
$keystone_db_name = 'keystone'
$keystone_db_pass = 'labkeystone01'

$glance_db_user = 'glance'
$glance_db_name = 'glance'
$glance_db_pass = 'labglance01'

$nova_db_user = 'nova'
$nova_db_name = 'nova'
$nova_db_pass = 'labnova01'
$nova_metadata_secret = 'secret'

$neutron_db_user = 'neutron'
$neutron_db_name = 'neutron'
$neutron_db_pass = 'labneutron01'

$cinder_db_user = 'cinder'
$cinder_db_name = 'cinder'
$cinder_db_pass = 'labcinder01'

$telemetry_secret   = 'labceilometer01'
$ceilometer_db_user = 'ceilometer'
$ceilometer_db_name = 'ceilometer'
$ceilometer_db_pass = 'labceilometer01'

$heat_db_user  = 'heat'
$heat_db_name  = 'heat'
$heat_db_pass  = 'labheat01'
$heat_encryption_key = 'labheat01'

node default {
    package { 'ubuntu-cloud-keyring':
        ensure     => 'latest',
    }
    apt::source { 'puppetlabs':
        location   => 'http://apt.puppetlabs.com',
        repos      => 'main',
        key        => '1054B7A24BD6EC30',
        key_server => 'pgp.mit.edu',
    }
    apt::source { 'cloudarchive-juno':
        location   => 'http://ubuntu-cloud.archive.canonical.com/ubuntu',
        release    => '',
        repos      => 'trusty-updates/juno main',
        require    => Package['ubuntu-cloud-keyring'],
        before     => Class[
            'nova',
            'nova::compute',
            'neutron',
            'neutron::plugins::ml2',
            'glance',
            'cinder',
            'ceilometer',
            'keystone',
            'horizon'
        ],
    }
}

### Controller
node /^.*controller.*$/ {
    
    ### MySql
    class { '::mysql::server':
        root_password => $db_root_pw,
    }
    mysql::db { $keystone_db_name:
        user     => $keystone_db_user,
        password => $keystone_db_pass,
        host     => '%',
        before   => Class['keystone'],
    }
    mysql::db { $glance_db_name:
        user     => $glance_db_user,
        password => $glance_db_pass,
        host     => '%',
        before   => Class['glance'],
    }
    mysql::db { $nova_db_name:
        user     => $nova_db_user,
        password => $nova_db_pass,
        host     => '%',
        before   => Class['nova'],
    }
    mysql::db { $neutron_db_name:
        user     => $neutron_db_user,
        password => $neutron_db_pass,
        host     => '%',
        before   => Class['neutron'],
    }
    mysql::db { $cinder_db_name:
        user     => $cinder_db_user,
        password => $cinder_db_pass,
        host     => '%',
        before   => Class['cinder'],
    }
    mysql::db { $ceilometer_db_name:
        user     => $ceilometer_db_user,
        password => $ceilometer_db_pass,
        host     => '%',
        before   => Class['ceilometer','ceilometer::db'],
    }
    mysql::db { $heat_db_name:
        user     => $heat_db_user,
        password => $heat_db_pass,
        host     => '%',
        before   => Class['heat'],
    }


    ### RabbitMQ
    class { '::rabbitmq':
        port                => $rabbit_port,
        default_user        => $rabbit_user,
        default_pass        => $rabbit_pass,
    }

    ### Keystone (Auth)
    class { '::keystone':
        admin_token     => $keystone_admin_token,
        catalog_type    => 'sql',
        rabbit_host     => "$rabbit_address",
        rabbit_password => $rabbit_pass,
        rabbit_userid   => $rabbit_user,
        sql_connection  => "mysql://${keystone_db_user}:${keystone_db_pass}@${db_host}:3306/${keystone_db_name}",
        token_driver    => 'keystone.token.backends.sql.Token',
        verbose         => False,
        debug           => False,
    }
    class { '::keystone::roles::admin':
        email       => $openstack_admin_mail,
        password    => $openstack_admin_pass,
    }
    class { '::keystone::endpoint':
        public_address   => $ext_address,
        admin_address    => $api_address,
        internal_address => $api_address,
        region           => $openstack_region,
    }

    ### Glance (Image)
    class { '::glance::api':
        debug               => False,
        verbose             => False,
        keystone_tenant     => 'services',
        keystone_user       => $glance_db_user,
        keystone_password   => $glance_db_pass,
        sql_connection      => "mysql://${glance_db_user}:${glance_db_pass}@${db_host}:3306/${glance_db_name}",
    }
    class { '::glance::registry':
        debug               => False,
        verbose             => False,
        keystone_tenant     => 'services',
        keystone_user       => $glance_db_user,
        keystone_password   => $glance_db_pass,
        sql_connection      => "mysql://${glance_db_user}:${glance_db_pass}@${db_host}:3306/${glance_db_name}",
    }
    class { '::glance::notify::rabbitmq':
        rabbit_host     => $rabbit_address,
        rabbit_userid   => $rabbit_user,
        rabbit_password => $rabbit_pass,
    }
    class { '::glance::backend::file': }
    class { 'glance::keystone::auth':
        password         => $glance_db_pass,
        email            => 'glance@diegolima.org',
        public_address   => $ext_address,
        admin_address    => $api_address,
        internal_address => $api_address,
        region           => $openstack_region,
    }

    
    ### Nova (Compute)
    class { '::nova':
        database_connection => "mysql://${nova_db_user}:${nova_db_pass}@${db_host}/${nova_db_name}",
        rabbit_userid       => $rabbit_user,
        rabbit_password     => $rabbit_pass,
        image_service       => 'nova.image.glance.GlanceImageService',
        glance_api_servers  => "${api_address}:9292",
        debug               => False,
        verbose             => False,
        rabbit_host         => "${rabbit_address}",
    }
    class { '::nova::network::neutron':
        neutron_admin_password  => $neutron_db_password,
        neutron_url             => "http://${api_address}:9696",
        neutron_region_name     => $openstack_region,
    }
    class { '::nova::keystone::auth':
        password    => $nova_db_pass,
        email       => 'nova@diegolima.org',
        public_address   => $ext_address,
        admin_address    => $api_address,
        internal_address => $api_address,
        region           => $openstack_region,
    }
    class { '::nova::conductor':
        enabled => true,
    }
    class { '::nova::api':
        enabled         => true,
        sync_db         => true,
        admin_password  => $nova_db_pass,
        neutron_metadata_proxy_shared_secret => $nova_metadata_secret,
    }
    class { '::nova::cert':
        enabled => true,
    }
    class { '::nova::consoleauth':
        enabled => true,
    }
    class { '::nova::scheduler':
        enabled => true,
    }
    class { '::nova::vncproxy':
        enabled => true,
    }


    ### Neutron (Network)
    class { '::neutron':
        enabled         => true,
        bind_host       => '0.0.0.0',
        rabbit_host     => $api_address,
        rabbit_user     => $rabbit_user,
        rabbit_password => $rabbit_pass,
        verbose         => false,
        debug           => false,
        core_plugin     => 'ml2',
        service_plugins => [ 'router' ],
    }
    class { '::neutron::keystone::auth':
        password    => $neutron_db_pass,
        email       => 'neutron@diegolima.org',
        public_address   => $ext_address,
        admin_address    => $api_address,
        internal_address => $api_address,
        region           => $openstack_region,
    }
    class { 'neutron::server':
        auth_host       => $api_address,
        auth_password   => $neutron_db_pass,
        sql_connection  => "mysql://${neutron_db_user}:${neutron_db_pass}@${db_host}/${neutron_db_name}",
    }
    class { '::neutron::server::notifications':
        nova_url            => "http://${api_address}:8774/v2",
    nova_admin_auth_url => "http://${api_address}:35357/v2.0",
        nova_admin_password => $nova_db_pass,
        nova_region_name    => $openstack_region,
    }
    class { '::neutron::plugins::ml2':
        type_drivers            => [ 'flat', 'gre', ],
        tenant_network_types    => [ 'gre', ],
        mechanism_drivers       => [ 'openvswitch' ],
        tunnel_id_ranges        => ['1:1000'],
    }

    ### Cinder (Volume)
    class { '::cinder' :
        database_connection     => "mysql://${cinder_db_user}:${cinder_db_pass}@${db_host}/${cinder_db_name}",
        rabbit_userid           => $rabbit_user,
        rabbit_password         => $rabbit_pass,
        rabbit_host             => $api_address,
        verbose                 => true,
    }
    class { '::cinder::keystone::auth':
        password                => $cinder_db_pass,
        email                   => 'cinder@diegolima.org',
        public_address          => $ext_address,
        admin_address           => $api_address,
        internal_address        => $api_address,
        region                  => $openstack_region,
    }
    class { '::cinder::api':
        keystone_password       => $cinder_db_pass,
        keystone_auth_host      => $api_address,
    }
    class { '::cinder::scheduler':
        scheduler_driver => 'cinder.scheduler.simple.SimpleScheduler',
    }
    class { '::cinder::ceilometer': }

    ### Cinder (Volume, storage node)
    class { '::cinder::volume': }

    class { '::cinder::volume::iscsi':
        iscsi_ip_address => $network_eth0,
    }


    ### Horizon (Dashboard)
    class { 'memcached':
        listen_ip => $api_address,
        tcp_port  => '11211',
        udp_port  => '11211',
    }
    class { '::horizon':
        configure_apache    => true,
        cache_server_ip     => $api_address,
        cache_server_port   => '11211',
        secret_key          => '12345',
        swift               => false,
        django_debug        => 'False',
        api_result_limit    => '2000',
        servername          => 'default',
        allowed_hosts       => '*',
    }

    ### Ceilometer (Telemetry)
    class { '::ceilometer::db':
        database_connection => "mysql://${ceilometer_db_user}:${ceilometer_db_pass}@${db_host}/${ceilometer_db_name}"
    }
    class { '::ceilometer':
        metering_secret     => $telemetry_secret,
        rabbit_host         => $rabbit_address,
        rabbit_userid       => $rabbit_user,
        rabbit_password     => $rabbit_pass,
    }
    class { '::ceilometer::api':
        keystone_host               => $api_address,
        keystone_user               => $ceilometer_db_user,
        keystone_password           => $ceilometer_db_pass,
    }
    class { '::ceilometer::keystone::auth':
        password        => $ceilometer_db_pass,
        public_address  => $ext_address,
        admin_address   => $api_address,
        internal_address=> $api_address,
        region          => $openstack_region,
    }
    class { '::ceilometer::agent::auth':
        auth_url            => "http://${api_address}:5000/v2.0",
        auth_region         => $openstack_region,
        auth_user           => $ceilometer_db_user,
        auth_password       => $ceilometer_db_pass,
    }
    class { '::ceilometer::collector': }
    class { '::ceilometer::agent::central': }
    class { '::ceilometer::agent::notification': }
    class { '::ceilometer::alarm::evaluator': }
    class { '::ceilometer::alarm::notifier': }

    # Heat (Orchestration)
    class { '::heat':
        rabbit_host       => $rabbit_address,
        rabbit_userid     => $rabbit_user,
        rabbit_password   => $rabbit_pass,
        keystone_host     => $api_address,
        keystone_user     => $heat_db_user,
        keystone_password => $heat_db_pass,
        database_connection => "mysql://${heat_db_user}:${heat_db_pass}@${db_host}/${heat_db_name}",
    }
    class { '::heat::keystone::auth':
        auth_name       => $heat_db_user,
        password        => $heat_db_pass,
        public_address  => $ext_address,
        admin_address   => $api_address,
        internal_address=> $api_address,
        region          => $openstack_region,
    }
    class { '::heat::api': }
    class { '::heat::api_cfn': }
    class { '::heat::engine':
        auth_encryption_key             => $heat_encryption_key,
        heat_metadata_server_url        => "http://${api_address}:8000",
        heat_waitcondition_server_url   => "http://${api_address}:8000/v1/waitcondition",
        heat_watch_server_url           => "http://${api_address}:8003",
    }
}

### Network Node
node /^.*network.*$/ {
    class { '::neutron':
        enabled         => true,
        bind_host       => '0.0.0.0',
        rabbit_host     => $api_address,
        rabbit_user     => $rabbit_user,
        rabbit_password => $rabbit_pass,
        verbose         => false,
        debug           => false,
        core_plugin     => 'ml2',
        service_plugins => [ 'router' ],
    }
    class { '::neutron::plugins::ml2':
        type_drivers            => [ 'flat', 'gre', ],
        tenant_network_types    => [ 'gre', ],
        mechanism_drivers       => [ 'openvswitch' ],
        tunnel_id_ranges        => ['1:1000'],
    }
    class { '::neutron::agents::ml2::ovs':
        enabled             => true,
        tunnel_types        => [ 'gre', ],
        bridge_mappings     => [ 'external:br-ex', ],
        enable_tunneling    => true,
        local_ip            => $network_node_int_iface,
    }
    class { '::neutron::agents::l3':
        enabled         => true,
        use_namespaces  => true,
        gateway_external_network_id  => '',
        handle_internal_only_routers => true,
    }
    class { '::neutron::agents::dhcp':
        enabled         => true,
    }
    class { '::neutron::agents::metadata':
        enabled         => true,
        auth_password   => $neutron_db_pass,
        shared_secret   => $nova_metadata_secret,
        auth_url        => "http://${api_address}:35357/v2.0",
        auth_region     => $openstack_region,
        metadata_ip     => $api_address,
    }
}

### Compute Node
node /^.*compute.*$/ {
    class { '::neutron':
        enabled         => true,
        bind_host       => '0.0.0.0',
        rabbit_host     => $api_address,
        rabbit_user     => $rabbit_user,
        rabbit_password => $rabbit_pass,
        verbose         => false,
        debug           => false,
        core_plugin     => 'ml2',
        service_plugins => [ 'router' ],
    }
    class { '::neutron::plugins::ml2':
        type_drivers            => [ 'flat', 'gre', ],
        tenant_network_types    => [ 'gre', ],
        mechanism_drivers       => [ 'openvswitch' ],
        tunnel_id_ranges        => ['1:1000'],
    }
    class { '::neutron::agents::ml2::ovs':
        enabled             => true,
        tunnel_types        => [ 'gre', ],
        enable_tunneling    => true,
        local_ip            => $compute_node_int_iface,
    }
    class { '::nova':
        database_connection => "mysql://${nova_db_user}:${nova_db_pass}@${db_host}/${nova_db_name}",
        rabbit_userid       => $rabbit_user,
        rabbit_password     => $rabbit_pass,
        image_service       => 'nova.image.glance.GlanceImageService',
        glance_api_servers  => "${api_address}:9292",
        debug               => False,
        verbose             => False,
        rabbit_host         => "${rabbit_address}",
    }
    class { '::nova::compute':
        enabled         => true,
        neutron_enabled => true,
        vncproxy_host   => $ext_address,
        vncserver_proxyclient_address   => $compute_node_mgt_iface,
    }
    class { '::nova::compute::libvirt':
        libvirt_virt_type   => 'qemu',
        vncserver_listen    => '0.0.0.0',
        migration_support   => true,
    }
    class { '::nova::network::neutron':
        neutron_admin_password  => $neutron_db_pass,
        neutron_url             => "http://${api_address}:9696",
        neutron_admin_auth_url  => "http://${api_address}:35357/v2.0",
        neutron_region_name     => $openstack_region,
    }
    
    class { '::ceilometer::db':
        database_connection => "mysql://${ceilometer_db_user}:${ceilometer_db_pass}@${db_host}/${ceilometer_db_name}"
    }
    class { '::ceilometer':
        metering_secret     => $telemetry_secret,
        rabbit_host         => $rabbit_address,
        rabbit_userid       => $rabbit_user,
        rabbit_password     => $rabbit_pass,
    }
    class { '::ceilometer::agent::auth':
        auth_url            => "http://${api_address}:35357/v2.0",
        auth_region         => $openstack_region,
        auth_user           => $ceilometer_db_user,
        auth_password       => $ceilometer_db_pass,
    }
    class { '::ceilometer::agent::compute': }
}
