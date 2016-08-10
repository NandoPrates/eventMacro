package eventMacro::Automacro;

use strict;
use Globals;
use Log qw(message error warning debug);
use Utils;
use eventMacro::Condition;

sub new {
	my ($class, $name, $conditions, $parameters) = @_;
	my $self = bless {}, $class;
	
	$self->{Name} = $name;
	
	$self->{conditionList} = new eventMacro::Lists;
	$self->{event_only_condition_index} = undef;
	$self->{hooks} = {};
	$self->{variables} = {};
	$self->create_conditions_list( $conditions );
	
	$self->{number_of_false_conditions} = $self->{conditionList}->size;
	if (defined $self->{event_only_condition_index}) {
		$self->{number_of_false_conditions}--;
	}
	
	$self->{Parameters} = {};
	$self->set_parameters( $parameters );
	
	return $self;
}

sub get_hooks {
	my ($self) = @_;
	return $self->{hooks};
}

sub get_variables {
	my ($self) = @_;
	return $self->{variables};
}

sub get_name {
	my ($self) = @_;
	return $self->{Name};
}

sub set_timeout_time {
	my ($self, $time) = @_;
	$self->{Parameters}{time} = $time;
}

sub disable {
	my ($self) = @_;
	$self->{Parameters}{disabled} = 1;
	debug "[eventMacro] Disabling ".$self->get_name()."\n", "eventMacro", 2;
	return 1;
}

sub enable {
	my ($self) = @_;
	$self->{Parameters}{disabled} = 0;
	debug "[eventMacro] Enabling ".$self->get_name()."\n", "eventMacro", 2;
	return 1;
}

sub get_parameter {
	my ($self, $parameter) = @_;
	return $self->{Parameters}{$parameter};
}

sub set_parameters {
	my ($self, $parameters) = @_;
	foreach (keys %{$parameters}) {
		my $key = $_;
		my $value = $parameters->{$_};
		$self->{Parameters}{$key} = $value;
	}
	#all parameters must be defined
	if (!defined $self->{Parameters}{'timeout'})  {
		$self->{Parameters}{'timeout'} = 0;
	}
	if (!defined $self->{Parameters}{'delay'})  {
		$self->{Parameters}{'delay'} = 0;
	}
	if (!defined $self->{Parameters}{'run-once'})  {
		$self->{Parameters}{'run-once'} = 0;
	}
	if (!defined $self->{Parameters}{'disabled'})  {
		$self->{Parameters}{'disabled'} = 0;
	}
	if (!defined $self->{Parameters}{'overrideAI'})  {
		$self->{Parameters}{'overrideAI'} = 0;
	}
	if (!defined $self->{Parameters}{'orphan'})  {
		$self->{Parameters}{'orphan'} = $config{eventMacro_orphans};
	}
	if (!defined $self->{Parameters}{'macro_delay'})  {
		$self->{Parameters}{'macro_delay'} = $timeout{eventMacro_delay}{timeout};
	}
	if (!defined $self->{Parameters}{'priority'})  {
		$self->{Parameters}{'priority'} = 0;
	}
	if (!defined $self->{Parameters}{'exclusive'})  {
		$self->{Parameters}{'exclusive'} = 0;
	}
	if (!defined $self->{Parameters}{'repeat'})  {
		$self->{Parameters}{'repeat'} = 1;
	}
	$self->{Parameters}{time} = 0;
}

sub create_conditions_list {
	my ($self, $conditions) = @_;
	foreach (keys %{$conditions}) {
		my $module = $_;
		my $conditionsText = $conditions->{$_};
		eval "use $module";
		foreach my $newConditionText ( @{$conditionsText} ) {
			my $cond = $module->new( $newConditionText );
			$self->{conditionList}->add( $cond );
			foreach my $hook ( @{ $cond->get_hooks() } ) {
				push ( @{ $self->{hooks}{$hook} }, $cond->{listIndex} );
			}
			foreach my $variable ( @{ $cond->get_variables() } ) {
				push ( @{ $self->{variables}{$variable} }, $cond->{listIndex} );
			}
			if ($cond->is_event_only()) {
				$self->{event_only_condition_index} = $cond->{listIndex};
			}
		}
	}
}

sub has_event_only_condition {
	my ($self) = @_;
	return defined $self->{event_only_condition_index};
}

sub get_event_only_condition_index {
	my ($self) = @_;
	return $self->{event_only_condition_index};
}

sub check_normal_condition {
	my ($self, $condition_index, $event_name, $args) = @_;
	
	my $condition = $self->{conditionList}->get($condition_index);
	
	my $pre_check_status = $condition->is_fulfilled;
	
	$condition->validate_condition_status($event_name,$args);
	
	my $pos_check_status = $condition->is_fulfilled;
	
	debug "[eventMacro] Checking condition '".$condition->get_name()."' of index '".$condition->{listIndex}."' in automacro '".$self->{Name}."', fulfilled value before: '".$pre_check_status."', fulfilled value after: '".$pos_check_status."'.\n", "eventMacro", 3;
	
	if ($pre_check_status == 1 && $condition->is_fulfilled == 0) {
		$self->{number_of_false_conditions}++;
	} elsif ($pre_check_status == 0 && $condition->is_fulfilled == 1) {
		$self->{number_of_false_conditions}--;
	}
}

sub check_event_only_condition {
	my ($self, $event_name, $args) = @_;
	
	my $condition = $self->{conditionList}->get($self->{event_only_condition_index});
	
	my $return = $condition->validate_condition_status($event_name, $args);
	
	debug "[eventMacro] Checking event only condition '".$condition->get_name()."' of index '".$condition->{listIndex}."' in automacro '".$self->{Name}."', fulfilled value: '".$return."'.\n", "eventMacro", 3;

	return $return;
}

sub are_conditions_fulfilled {
	my ($self) = @_;
	$self->{number_of_false_conditions} == 0;
}

sub is_disabled {
	my ($self) = @_;
	return $self->{Parameters}{disabled};
}

sub is_timed_out {
	my ($self) = @_;
	return 1 unless ( $self->{Parameters}{'timeout'} );
	return 1 if ( timeOut( { timeout => $self->{Parameters}{'timeout'}, time => $self->{Parameters}{time} } ) );
	return 0;
}

sub can_be_run {
	my ($self) = @_;
	return 1 if ($self->are_conditions_fulfilled && !$self->is_disabled && $self->is_timed_out);
	return 0;
}

1;