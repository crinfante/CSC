package Bio::Graphics::Browser2::Plugin::CNEPlotInstance6;
use strict;
use vars '@ISA';
#use lib '/home/engstrom/DEVEL/CNE/lib';
use Bio::Graphics::Browser2::Plugin::CNEPlot;
@ISA = qw(Bio::Graphics::Browser2::Plugin::CNEPlot);


sub static_plugin_setting {
    my ($self, $name) = @_;
    return $self->browser_config->plugin_setting($name);
}
