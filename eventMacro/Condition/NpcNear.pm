package eventMacro::Condition::NpcNear;

use strict;
use Globals;
use Utils;

use base 'eventMacro::Condition::BaseActorNear';

sub _hooks {
	my ( $self ) = @_;
	my $hooks = $self->SUPER::_hooks;
	my @other_hooks = ('add_npc_list','npc_disappeared','npcNameUpdate');
	push(@{$hooks}, @other_hooks);
	return $hooks;
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'hook') {
		$self->{actorList} = $npcsList;
		if ($callback_name eq 'add_npc_list') {
			$self->{actor} = $args;
			$self->{hook_type} = 'add_list';

		} elsif ($callback_name eq 'npc_disappeared') {
			$self->{actor} = $args->{npc};
			$self->{hook_type} = 'disappeared';
		
		} elsif ($callback_name eq 'npcNameUpdate') {
			$self->{actor} = $args->{npc};
			$self->{hook_type} = 'NameUpdate';
		}
	}
	
	return $self->SUPER::validate_condition( $callback_type, $callback_name, $args );
}

sub usable {
	1;
}

1;
