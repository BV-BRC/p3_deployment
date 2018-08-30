package Bio::P3::DeploymentConfig;

use strict;
use base 'Class::Accessor';
use Config::Simple;
use Data::Dumper;

__PACKAGE__->mk_accessors(qw(service_name settings));

=head1 NAME

Bio::P3::DeploymentConfig

=head1 DESCRIPTION

The C<Bio::P3::DeploymentConfig> class wraps the access to a P3 deployment.cfg
file. It tests for the existence of the KB_DEPLOYMENT_CONFIG and 
KB_SERVICE_NAME environment variables; if both are present, the 
configuration parameters for the given service will be loaded 
from that config file. If they are not present, the module supports
fallback to defaults as defined by the module.

=head1 METHODS

=over 4

=cut

=item C<new>

    my $cfg = Bio::P3::DeploymentConfig->new($service_name, { name => 'value', ...})

Create a new C<Bio::P3::DeploymentConfig> instance.

Parameters:

=over 4

=item C<$service_name>

The name of this service, used as a default if C<KB_SERVICE_NAME> is not defined.

=item C<$defaults>

A hash reference containing the default values for the service parameters.

=back

=cut
   
sub new
{
    my($class, $service_name, $defaults) = @_;

    if ((my $n = $ENV{KB_SERVICE_NAME}) ne "")
    {
	$service_name = $n;
    }

    my $settings = {};
    if (ref($defaults))
    {
	%$settings = %$defaults;
    }

    my $cfg_file = $ENV{KB_DEPLOYMENT_CONFIG};
    if (-e $cfg_file)
    {
	my $cfg = Config::Simple->new();
	$cfg->read($cfg_file);
	patch_config($cfg);

	my %cfg = $cfg->vars;

	for my $k (keys %cfg)
	{
	    if ($k =~ /^$service_name\.(.*)/)
	    {
		$settings->{$1} = $cfg{$k};
	    }
	}
    }

    my $self = {
	settings => $settings,
	service_name => $service_name,
    };

    return bless $self, $class;
}

=item C<patch_config>
    
Enable a workaround for the access by directory name (e.g. genome_anntation)
and access by service name (e.g. GenomeAnnotation).

We do this by looking in each block for a setting of _service_name. If that exists,
we will replicate the contents block into a block named with the value
of the _service_name attribute.

=cut
    
sub patch_config
{
    my($cfg) = @_;

    my @patch_list;
    for my $name ($cfg->param())
    {
	my($k, $v) = split(/\./, $name, 2);
	if ($v eq '_service_name')
	{
	    push(@patch_list, [$k, $cfg->param($name)]);
	}
    }

    for my $patch (@patch_list)
    {
	my($existing, $new) = @$patch;
	#
	# Test to see if the mapped block exists.
	#
	my $new_blk = $cfg->get_block($new);
	if (%$new_blk)
	{
	    warn "Patching service name for $existing: service name $new already exists\n";
	    next;
	}
	my $blk = $cfg->get_block($existing);
	$cfg->set_block($new, $blk);
    }
}



=item C<setting>

Retrieve a setting from the configuration.

   my $value = $obj->setting("key-name");

=cut

sub setting
{
    my($self, $key) = @_;
    return $self->{settings}->{$key};
}

=item C<service_name>

Return the name of the service currently configured.

    my $name = $obj->service_name();

=cut

1;
