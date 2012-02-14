use strict;
use ModelSEED::FIGMODEL;
use Data::Dumper;

package ModelSEED::FIGMODEL::FIGMODELmodel;

=head1 FIGMODELmodel object
=head2 Introduction
Module for manipulating model objects.
=head2 Core Object Methods

=head3 new
Definition:
	FIGMODELmodel = FIGMODELmodel->new();
Description:
	This is the constructor for the FIGMODELmodel object.
=cut
sub new {
	my ($class,$figmodel,$id,$metagenome,$modelObj) = @_;
	#Error checking first
	if (!defined($figmodel)) {
		print STDERR "FIGMODELmodel->new(undef,".$id."):figmodel must be defined to create a model object!\n";
		return undef;
	}
	my $self = {_figmodel => $figmodel};
	bless $self;
	if (!defined($id)) {
		$self->figmodel()->error_message("FIGMODELmodel->new(figmodel,undef):id must be defined to create a model object");
		return undef;
	}
	#Setting the ppo object from input as needed when the model is first built
	if (defined($modelObj)) {
		$self->ppo($modelObj);
		$self->figmodel()->{_models}->{$id} = $self;
		$self->{_modeltype} = "genome";
	} else {
		#Checking that the id exists		
		if ($id =~ m/^\d+$/) {
			my $objects = $self->figmodel()->database()->get_objects("model");
			if (defined($objects->[$id])) {
				$self->ppo($objects->[$id]);
				$self->figmodel()->{_models}->{$id} = $self;
			}
		} else {
			my $object = $self->figmodel()->database()->get_object("model",{id => $id});
			if (defined($object)) {
				$self->ppo($object);
			}
		}
	}
	if (!defined($self->ppo())) {
		$self->figmodel()->error_message("FIGMODELmodel->new(figmodel,".$id."):could not find model ".$id." in database!");
		return undef;
	}
	$self->figmodel()->{_models}->{$self->id()} = $self;
	return $self;
}

=head3 config
Definition:
	ref::key value = FIGMODELmodel->config(string::key);
Description:
	Trying to avoid using calls that assume configuration data is stored in a particular manner.
	Call this function to get file paths etc.
=cut
sub config {
	my ($self,$key) = @_;
	return $self->figmodel()->config($key);
}

=head3 error_message
Definition:
	string:message text = FIGMODELmodel->error_message(string::message);
Description:
=cut
sub error_message {
	my ($self,$message) = @_;
	return $self->figmodel()->error_message("FIGMODELmodel:".$self->id().":".$message);
}
=head3 globalMessage
Definition:
	{} = FIGMODELmodel->globalMessage({
		function => "UNKNOWN",
		package => "FIGMODELmodel",
		user => FIGMODELmodel->figmodel()->user(),
		time => time(),
		id => FIGMODELmodel->id(),
		message => string,
		thread => "stdout",
	});
Description:
=cut
sub globalMessage {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["message"],{
		function => "UNKNOWN",
		package => "FIGMODELmodel",
		user => $self->figmodel()->user(),
		time => $self->figmodel()->timestamp(),
		id => $self->id(),
		thread => "stdout"
	});
	if (defined($args->{error})) {return $self->error_message({function => "globalMessage",args => $args});}
	return $self->figmodel()->globalMessage($args);
}

sub getCache {
	my ($self,$key) = @_;
	return $self->figmodel()->getCache({package=>"FIGMODELmodel",id=>$self->id(),key=>$key});
}

sub setCache {
	my ($self,$key,$data) = @_;
	return $self->figmodel()->setCache({package=>"FIGMODELmodel",id=>$self->id(),key=>$key,data=>$data});
}

=head3 aquireModelLock
Definition:
	FIGMODELmodel->aquireModelLock();
Description:
	Locks the database for alterations relating to the current model object
=cut
sub aquireModelLock {
	my ($self) = @_;
	$self->figmodel()->database()->genericLock($self->id());
}

=head3 releaseModelLock
Definition:
	FIGMODELmodel->releaseModelLock();
Description:
	Unlocks the database for alterations relating to the current model object
=cut
sub releaseModelLock {
	my ($self) = @_;
	$self->figmodel()->database()->genericUnlock($self->id());
}

=head3 delete
Definition:
	FIGMODEL = FIGMODELmodel->delete();
Description:
	Deletes the model object
=cut
sub delete {
	my ($self) = @_;
	my $directory = $self->directory();
	my $id = $self->id();
	if (length($id) > 0) {
		chomp($directory);
		print "Deleting directory ".$directory."\n"; 
		system("rm -rf ".$directory);
	}
	$self->figmodel()->database()->delete_object({type => "model",object => $self->ppo(),recursive => 1});
}

=head3 copyModel
Definition:
	FIGMODEL = FIGMODELmodel->copyModel({newID=>string});
Description:
	Copys the model to a new location and ID
=cut
sub copyModel {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{newid=>undef,owner=>undef});
	if (defined($args->{error})) {return $self->error_message({function => "copyModel",args => $args});}
	if (!defined($args->{owner}) && !defined($args->{newid})) {
		return $self->error_message({message=> "Must supply either username or new model ID",function => "copyModel",args => $args});
	}
	if (!defined($args->{owner})) {
		$args->{owner} = $self->figmodel()->user();
	}
	my $usrObj = $self->figmodel()->database()->get_object("user",{login=>$args->{owner}});
	if (!defined($args->{newid})) {
		$args->{newid} = "Seed".$self->genome().".".$usrObj->_id();
		my $index = 0;
		my $originalID = $args->{newid};
		while(defined($self->figmodel()->database()->get_object("model",{id=>$args->{newid}}))) {
			$args->{newid} = $originalID.".".$index;
			$index++;
		}
	}
	if (defined($self->figmodel()->database()->get_object("model",{id=>$args->{newid}}))) {
		return $self->error_message({message=> "A model with the suppied ID already exists",function => "copyModel",args => $args});
	}
	$self->figmodel()->createNewModel({-runPreliminaryReconstruction=>0,-id=>$args->{newid},-genome=>$self->ppo()->genome(),-gapfilling=>0,-owner=>$args->{owner}});
	my $mdl = $self->figmodel()->get_model($args->{newid});
	$mdl->ppo()->biomassReaction($self->ppo()->biomassReaction());
	my $rxnTbl = $self->reaction_table(1);
	$rxnTbl->save($mdl->directory().$mdl->id().".txt");
	$mdl->ppo()->status($self->ppo()->status());
	$mdl->ppo()->public($self->ppo()->public());
	$mdl->ppo()->autocompleteDate($self->ppo()->autocompleteDate());
	$mdl->ppo()->autoCompleteMedia($self->ppo()->autoCompleteMedia());
	$mdl->ppo()->autoCompleteTime($self->ppo()->autoCompleteTime());
	$mdl->ppo()->message($self->ppo()->message());
	$mdl->ppo()->version($self->ppo()->version());
	$mdl->ppo()->autocompleteVersion($self->ppo()->autocompleteVersion());
	$mdl->ppo()->cellwalltype($self->ppo()->cellwalltype());
	$mdl->ppo()->source($self->ppo()->source());
	$mdl->ppo()->name($self->ppo()->name());
	my $rxn = $self->figmodel()->get_reaction($self->ppo()->biomassReaction());
	my $copy = $rxn->copyReaction({owner=>$args->{owner}});
	$mdl->ppo()->biomassReaction($copy->id());
	$rxnTbl = $mdl->reaction_table();
	my $row = $rxnTbl->get_row_by_key("LOAD",$self->ppo()->biomassReaction());
	$row->{LOAD}->[0] = $copy->id();
	$rxnTbl->save();
	$mdl->processModel();
}

=head3 figmodel
Definition:
	FIGMODEL = FIGMODELmodel->figmodel();
Description:
	Returns a FIGMODEL object
=cut
sub figmodel {
	my ($self) = @_;
	return $self->{_figmodel};
}

=head3 genomeObj
Definition:
	FIGMODELgenome = FIGMODELmodel->genomeObj();
Description:
	Returns the genome object for the model
=cut
sub genomeObj {
	my ($self) = @_;
	if (!defined($self->{_genomeObj})) {
		$self->{_genomeObj} = $self->figmodel()->get_genome($self->genome());
	}
	return $self->{_genomeObj};
}

=head3 ppo
Definition:
	FIGMODEL = FIGMODELmodel->ppo();
Description:
	Returns the ppo object for the model
=cut
sub ppo {
	my ($self,$object) = @_;
	if (defined($object)) {
		$self->{_data} = $object;
	}
	return $self->{_data};
}

=head3 id
Definition:
	string = FIGMODELmodel->id();
Description:
	Returns model id
=cut
sub id {
	my ($self) = @_;
	return $self->ppo()->id();
}

=head3 status
Definition:
	int::model status = FIGMODELmodel->status();
Description:
	Returns the current status of the SEED model associated with the input genome ID.
	model status = 1: model exists
	model status = 0: model is being built
	model status = -1: model does not exist
	model status = -2: model build failed
=cut
sub status {
	my ($self) = @_;
	return $self->ppo()->status();
}

=head3 message
Definition:
	string::model message = FIGMODELmodel->message();
Description:
	Returns a message associated with the models current status
=cut
sub message {
	my ($self) = @_;
	return $self->ppo()->message();
}

=head3 set_status
Definition:
	(success/fail) = FIGMODELmodel->set_status(int::new status,string::status message);
Description:
	Changes the current status of the SEED model
	new status = 1: model exists
	new status = 0: model is being built
	new status = -1: model does not exist
	new status = -2: model build failed
=cut
sub set_status {
	my ($self,$NewStatus,$Message) = @_;
	$self->ppo()->status($NewStatus);
	$self->ppo()->message($Message);
	return $self->config("SUCCESS")->[0];
}

=head3 genome
Definition:
	string = FIGMODELmodel->genome();
Description:
	Returns model genome
=cut
sub genome {
	my ($self) = @_;
	return $self->ppo()->genome();
}

=head3 source
Definition:
	string = FIGMODELmodel->source();
Description:
	Returns model source
=cut
sub source {
	my ($self) = @_;
	return $self->ppo()->source();
}

=head3 get_model_type
Definition:
	string = FIGMODELmodel->get_model_type();
Description:
	Returns the type of the model
=cut
sub get_model_type {
	my ($self) = @_;
	if ($self->ppo()->source() =~ m/MGRAST/) {
		return "metagenome";
	}
	return "genome";
}

=head3 owner
Definition:
	string = FIGMODELmodel->owner();
Description:
	Returns the username for the model owner
=cut
sub owner {
	my ($self) = @_;
	return $self->ppo()->owner();
}

=head3 users
Definition:
	{string:user login => string:right} = FIGMODELmodel->users();
Description:
=cut
sub users {
	my ($self) = @_;
	if (!defined($self->{_userRightsHash})) {
		my $objs = $self->figmodel()->database()->get_objects("right",{data_id=>$self->ppo()->_id(),data_type=>$self->type()});
		for (my $i=0; $i < @{$objs}; $i++) {
			my $userscopes = $self->figmodel()->database()->get_objects("userscope",{scope=>$objs->[$i]->scope()});
			for (my $j=0; $j < @{$userscopes}; $j++) {
				my $user = 	$self->figmodel()->database()->get_object("user",{_id=>$userscopes->[$j]->user()});
				if (defined($self->{_userRightsHash}->{$user->login()})) {
					if ($objs->[$i]->name() eq "edit" && $self->{_userRightsHash}->{$user->login()} eq "view") {
						$self->{_userRightsHash}->{$user->login()} = $objs->[$i]->name();	
					} elsif ($objs->[$i]->name() eq "admin") {
						$self->{_userRightsHash}->{$user->login()} = $objs->[$i]->name();
					}
				} else {
					$self->{_userRightsHash}->{$user->login()} = $objs->[$i]->name();
				}
			}
		}
	}
	return $self->{_userRightsHash};
}

=head3 changeRight
Definition:
	string:error message = FIGMODELmodel->changeRight(string:username,string right);
=cut
sub changeRight {
	my ($self,$username,$right,$remove) = @_;
	delete $self->{_userRightsHash};
	if ($self->currentRight() ne "admin") {
		return $self->error_message("createRight: Cannot create rights without administrative privelages");	
	}
	my $backend = $self->figmodel()->database()->get_object("backend",{name=>"ModelSEED"});
	if (!defined($backend)) {
		return $self->error_message("changeRight:could not find backend ModelSEED!");	
	}
	my $scopeObj;
	$scopeObj = $self->figmodel()->database()->get_object("scope",{name=>"user:".$username});
	if (!defined($scopeObj)) {
		$scopeObj = $self->figmodel()->database()->get_object("scope",{_id => $username});	
	}
	if (!defined($scopeObj)) {
		return $self->error_message("changeRight:could not find scope ".$username."!");	
	}
	my $rightObj = $self->figmodel()->database()->get_object("right",{application=>$backend,scope=>$scopeObj,data_id=>$self->ppo()->_id(),data_type=>$self->type()});
	if (!defined($rightObj) && (!defined($remove) || $remove == 0)) {
		$self->figmodel()->database()->create_object("right",{granted=>1,
															  delegated=>0,
															  data_id=>$self->ppo()->_id(),
															  data_type=>$self->type(),
															  application=>$backend,
															  name=>$right,
															  scope=>$scopeObj});
	} elsif (defined($rightObj) && !defined($remove) || $remove == 0) {
		$rightObj->name($right);
		$rightObj->granted(1);
	} elsif (defined($rightObj) && defined($remove) && $remove == 1) {
		$rightObj->delete();
	}
}

=head3 currentRight
Definition:
	string:right = FIGMODELmodel->currentRight();
=cut
sub currentRight {
	my ($self) = @_;
	if (!defined($self->{_currentRight})) {		
		$self->{_currentRight} = $self->rights($self->figmodel()->user());
	}
	return $self->{_currentRight};
}

=head3 rights
Definition:
	1/0 = FIGMODELmodel->rights(string::username);
Description:
	Returns 1 if the input user can view the model, and zero otherwise
=cut
sub rights {
	my ($self,$username) = @_;
	if (!defined($self->{_userRightsHash}->{$username})) {
		if (defined($self->figmodel()->config("model administrators")->{$username}) || $username eq $self->owner()) {
			$self->{_userRightsHash}->{$username} = "admin";
		} elsif ($self->ppo()->public() == 1) {
			$self->{_userRightsHash}->{$username} = "view";
		} else {
			my $user = $self->figmodel()->database()->get_object("user",{login=>$username});
			my $userscopes = $self->figmodel()->database()->get_objects("userscope",{user=>$user->_id()});
			for (my $i=0; $i < @{$userscopes};$i++) {
				my $right = $self->figmodel()->database()->get_object("right",{data_type=>"model",data_id=>$self->ppo()->_id(),scope=>$userscopes->[$i]->_id()});
				if (defined($right)) {
					$self->{_userRightsHash}->{$username} = $right->name();
					last;
				}
			}
		}
		if (!defined($self->{_userRightsHash}->{$username})) {
			$self->{_userRightsHash}->{$username} = "none";
		}
	}
	return $self->{_userRightsHash}->{$username};
}

=head3 create_model_rights
Definition:
	string:error = FIGMODELmodel->create_model_rights();
Description:
	Creates rights associated with model. Should be called when models are first created.
=cut
sub create_model_rights {
	my ($self) = @_;
	if ($self->ppo()->owner() eq "master") {
		$self->ppo()->public(1);
	} else {
		$self->changeRight($self->ppo()->owner(),"admin");
		$self->ppo()->public(0);
	}
}

=head3 transfer_rights_to_biomass
Definition:
	string = FIGMODELmodel->transfer_rights_to_biomass();
Description:
	Transfers the rights for the model to the biomass reaction
=cut
sub transfer_rights_to_biomass {
	my ($self) = @_;
	my $bofObj = $self->biomassObject();
	if (!defined($bofObj)) {
		return $self->error_message("transfer_rights_to_biomass:could not find biomass reaction ".$self->biomassReaction()." in database!");	
	}
	$bofObj->public($self->ppo()->public());
	$bofObj->owner($self->ppo()->owner());
	my $rightObjs = $self->figmodel()->database()->get_objects("right",{data_type=>$self->type(),data_id=>$self->ppo()->_id()});
	my $bofRightObjs = $self->figmodel()->database()->get_objects("right",{data_type=>"bof",data_id=>$bofObj->_id()});
	my $scopeHash;
	for (my $i=0; $i < @{$rightObjs}; $i++) {
		my $found = 0;
		for (my $j=0; $j < @{$bofRightObjs}; $j++) {
			if ($rightObjs->[$i]->scope() eq $bofRightObjs->[$j]->scope()) {
				$scopeHash->{$rightObjs->[$i]->scope()} = 1;
				$found = 1;
				$bofRightObjs->[$j]->name($rightObjs->[$i]->name());
			}
		}
		if ($found == 0) {
			$self->figmodel()->database()->create_object("right",{data_type=>"bof",
																  data_id=>$bofObj->_id(),
																  name=>$rightObjs->[$i]->name(),
																  scope=>$rightObjs->[$i]->scope(),
																  granted=>1,
																  delegated=>0,
																  application=>$rightObjs->[$i]->application()});
		}
	}
	for (my $j=0; $j < @{$bofRightObjs}; $j++) {
		if (!defined($scopeHash->{$bofRightObjs->[$j]->scope()})) {
			$bofRightObjs->[$j]->delete();
		}	
	}
}

=head3 name
Definition:
	string = FIGMODELmodel->name();
Description:
	Returns the name of the organism or metagenome sample being modeled
=cut
sub name {
	my ($self) = @_;
	$self->ppo()->name();
}

=head3 get_reaction_class
Definition:
	string = FIGMODELmodel->get_reaction_class(string::reaction ID);
Description:
	Returns reaction class
=cut
sub get_reaction_class {
	my ($self,$reaction,$nohtml,$brief_flux) = @_;

	if (!-e $self->directory()."ReactionClassification-".$self->id().".tbl") {
		if (!defined($self->{_reaction_classes})) {
			$self->{_reaction_classes} = $self->figmodel()->database()->load_table($self->directory()."ReactionClassification-".$self->id()."-Complete.tbl",";","|",0,["REACTION"]);
			if (!defined($self->{_reaction_classes})) {
				return undef;
			}
		}

		my $ClassRow = $self->{_reaction_classes}->get_row_by_key($reaction,"REACTION");
		if (defined($ClassRow) && defined($ClassRow->{CLASS})) {
			my $class;
			my $min = $ClassRow->{MIN}->[0];
			my $max = $ClassRow->{MAX}->[0];
			if ($ClassRow->{CLASS}->[0] eq "Positive") {
				$class = "Essential =>";
				$brief_flux ? $class.="<br>[Flux: ".sprintf("%.3g",$min)." to ".sprintf("%.3g",$max)."]<br>" : $class.="<br>[Flux: ".$min." to ".$max."]<br>";
			} elsif ($ClassRow->{CLASS}->[0] eq "Negative") {
				$class = "Essential <=";
				$brief_flux ? $class.="<br>[Flux: ".sprintf("%.3g",$max)." to ".sprintf("%.3g",$min)."]<br>" : $class.="<br>[Flux: ".$max." to ".$min."]<br>";
			} elsif ($ClassRow->{CLASS}->[0] eq "Positive variable") {
				$class = "Active =>";
				$brief_flux ? $class.="<br>[Flux: ".sprintf("%.3g",$min)." to ".sprintf("%.3g",$max)."]<br>" : $class.="<br>[Flux: ".$min." to ".$max."]<br>";
			} elsif ($ClassRow->{CLASS}->[0] eq "Negative variable") {
				$class = "Active <=";
				$brief_flux ? $class.="<br>[Flux: ".sprintf("%.3g",$max)." to ".sprintf("%.3g",$min)."]<br>" : $class.="<br>[Flux: ".$max." to ".$min."]<br>";
			} elsif ($ClassRow->{CLASS}->[0] eq "Variable") {
				$class = "Active <=>";
				$brief_flux ? $class.="<br>[Flux: ".sprintf("%.3g",$min)." to ".sprintf("%.3g",$max)."]<br>" : $class.="<br>[Flux: ".$min." to ".$max."]<br>";
			} elsif ($ClassRow->{CLASS}->[0] eq "Blocked") {
				$class = "Inactive";
			} elsif ($ClassRow->{CLASS}->[0] eq "Dead") {
				$class = "Disconnected";
			}

			if (!defined($nohtml) || $nohtml ne "1") {
				$class = "<span title=\"Flux:".$min." to ".$max."\">".$class."</span>";
			}

			return $class;
		}
		return undef;
	}

	if (!defined($self->{_reaction_classes})) {
		$self->{_reaction_classes} = $self->figmodel()->database()->load_table($self->directory()."ReactionClassification-".$self->id().".tbl",";","|",0,["REACTION"]);
		if (!defined($self->{_reaction_classes})) {
			return undef;
		}
	}

	my $ClassRow = $self->{_reaction_classes}->get_row_by_key($reaction,"REACTION");
	my $classstring = "";
	if (defined($ClassRow) && defined($ClassRow->{CLASS})) {
		for (my $i=0; $i < @{$ClassRow->{CLASS}};$i++) {
			if (length($classstring) > 0) {
				$classstring .= "<br>";
			}
			my $NewClass;
			my $min = $ClassRow->{MIN}->[$i];
			my $max = $ClassRow->{MAX}->[$i];
			if ($ClassRow->{CLASS}->[$i] eq "Positive") {
				$NewClass = $ClassRow->{MEDIA}->[$i].":Essential =>";
				$brief_flux ? $NewClass.="<br>[Flux: ".sprintf("%.3g",$min)." to ".sprintf("%.3g",$max)."]<br>" : $NewClass.="<br>[Flux: ".$min." to ".$max."]<br>";
			} elsif ($ClassRow->{CLASS}->[$i] eq "Negative") {
				$NewClass = $ClassRow->{MEDIA}->[$i].":Essential <=";
				$brief_flux ? $NewClass.="<br>[Flux: ".sprintf("%.3g",$max)." to ".sprintf("%.3g",$min)."]<br>" : $NewClass.="<br>[Flux: ".$max." to ".$min."]<br>";
			} elsif ($ClassRow->{CLASS}->[$i] eq "Positive variable") {
				$NewClass = $ClassRow->{MEDIA}->[$i].":Active =>";
				$brief_flux ? $NewClass.="<br>[Flux: ".sprintf("%.3g",$min)." to ".sprintf("%.3g",$max)."]<br>" : $NewClass.="<br>[Flux: ".$min." to ".$max."]<br>";
			} elsif ($ClassRow->{CLASS}->[$i] eq "Negative variable") {
				$NewClass = $ClassRow->{MEDIA}->[$i].":Active <=";
				$brief_flux ? $NewClass.="<br>[Flux: ".sprintf("%.3g",$max)." to ".sprintf("%.3g",$min)."]<br>" : $NewClass.="<br>[Flux: ".$max." to ".$min."]<br>";
			} elsif ($ClassRow->{CLASS}->[$i] eq "Variable") {
				$NewClass = $ClassRow->{MEDIA}->[$i].":Active <=>";
				$brief_flux ? $NewClass.="<br>[Flux: ".sprintf("%.3g",$min)." to ".sprintf("%.3g",$max)."]<br>" : $NewClass.="<br>[Flux: ".$min." to ".$max."]<br>";
			} elsif ($ClassRow->{CLASS}->[$i] eq "Blocked") {
				$NewClass = $ClassRow->{MEDIA}->[$i].":Inactive";
			} elsif ($ClassRow->{CLASS}->[$i] eq "Dead") {
				$NewClass = $ClassRow->{MEDIA}->[$i].":Disconnected";
			}

			if (!defined($nohtml) || $nohtml ne "1") {
				$NewClass = "<span title=\"Flux:".$min." to ".$max."\">".$NewClass."</span>";
			}
			$classstring .= $NewClass;
		}
	}
	return $classstring;
}

=head3 get_biomass
Definition:
	string = FIGMODELmodel->get_biomass();
Description:
	Returns data for the biomass reaction
=cut
sub get_biomass {
	my ($self) = @_;
	return $self->get_reaction_data($self->ppo()->biomassReaction());
}

=head3 get_reaction_data
Definition:
	string = FIGMODELmodel->get_reaction_data(string::reaction ID <or> {-id=>string:reaction ID,-index=>integer:reaction index});
Description:
	Returns model reaction data
=cut
sub get_reaction_data {
	my ($self,$args) = @_;
	if (ref($args) ne "HASH") {
		if ($args =~ m/^\d+$/) {
			$args = {-index => $args};
		} elsif ($args =~ m/[rb][ix][no]\d\d\d\d\d/) {
			$args = {-id => $args};
		} else {
			$self->error_message("get_reaction_data:No ID or index specified!");
			return undef;
		}
	}
	if (!defined($args->{-id}) && !defined($args->{-index})) {
		$self->error_message("get_reaction_data:No ID or index specified!");
		return undef;
	}
	my $rxnTbl = $self->reaction_table();
	if (!defined($rxnTbl)) {
		return undef;
	}
	my $rxnData;
	if (defined($args->{-id})) {
		$rxnData = $rxnTbl->get_row_by_key($args->{-id},"LOAD");
	} elsif (defined($args->{-index})) {
		$rxnData = $rxnTbl->get_row($args->{-index});
	}
	return $rxnData;
}

=head3 getRoleTable
Definition:
	FIGMODELTable = FIGMODELmodel->getRoleTable();
Description:
	Returns a FIGMODELTable with data on functional roles
=cut
sub role_table {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{create=>0});
	if (defined($args->{error})) {return $self->error_message({function => "role_table",args => $args});}
	if (!defined($self->getCache("roletable"))) {
		my $tbl;
		if ($args->{create} == 1 || !-e $self->directory()."Roles.tbl") {
			my $pegTbl = $self->feature_table();
			$tbl = ModelSEED::FIGMODEL::FIGMODELTable->new(["ROLE","REACTIONS","GENES","ESSENTIAL"],$self->directory()."Roles.tbl",["ROLE","REACTIONS","GENES","ESSENTIAL"],";","|");
			my $gene;
			for(my $i=0; $i < $pegTbl->size(); $i++) {
				my $row = $pegTbl->get_row($i);
				if ($row->{ID}->[0] =~ m/(peg\.\d+)/) {
					$gene = $1;
					if (defined($row->{ROLES}->[0])) {
						for(my $j=0; $j < @{$row->{ROLES}}; $j++) {
							my $newrow = $tbl->get_row_by_key($row->{ROLES}->[$j],"ROLE",1);
							push(@{$newrow->{GENES}},$gene);
							if (defined($row->{$self->id()."PREDICTIONS"})) {
								my $essential = 0;
								for (my $k=0; $k < @{$row->{$self->id()."PREDICTIONS"}}; $k++) {
									if ($row->{$self->id()."PREDICTIONS"}->[$k] eq "Complete:essential") {
										$essential = 1;
									}
								}
								$newrow->{ESSENTIAL}->[0] = $essential;
							}
							if (defined($row->{$self->id()."REACTIONS"})) {
								for (my $k=0; $k < @{$row->{$self->id()."REACTIONS"}}; $k++) {
									$tbl->add_data($newrow,"REACTIONS",$row->{$self->id()."REACTIONS"}->[$k],1);
								}
							}
						}
					}
				}
			}
			my $gfroles = $self->gapfilled_roles();
			foreach my $gfrole (keys(%{$gfroles})) {
				my $newrow = $tbl->get_row_by_key($gfrole,"ROLE",1);
				$newrow->{REACTIONS} = $gfroles->{$gfrole};
				$newrow->{ESSENTIAL}->[0] = 1;
			}
			$tbl->save();
		} else {
			$tbl = $self->figmodel()->database()->load_table($self->directory()."Roles.tbl",";","|",0,["ROLE","REACTIONS","GENES","ESSENTIAL"]);		
		}
		$self->setCache("roletable",$tbl);
	}
	return $self->getCache("roletable");
}
=head3 reaction_notes
Definition:
	string = FIGMODELmodel->reaction_notes(string::reaction ID);
Description:
	Returns reaction notes
=cut
sub reaction_notes {
	my ($self,$rxn) = @_;
	my $rxnTbl = $self->reaction_table();
	if (!defined($rxnTbl)) {
		return "None";
	}
	my $rxnData = $rxnTbl->get_row_by_key($rxn,"LOAD");;
	if (!defined($rxnData)) {
		return "Not in model";	
	}
	if (defined($rxnData->{NOTES})) {
		return join("<br>",@{$rxnData->{NOTES}});
	} 
	return "None"
}

=head3 display_reaction_flux
Definition:
	string = FIGMODELmodel->get_reaction_flux({id => string:reaction id,fluxobj => PPOfbaresult:PPO object with flux data});
Description:
	Returns the flux associated with the specified reaction in the fba results databases
=cut
sub get_reaction_flux {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["id","fluxobj"]);
	if (defined($args->{error})) {
		$self->error_message("get_reaction_flux:".$args->{error});
		return undef;
	}
	if (!defined($self->{_fluxes}->{$args->{fluxobj}->_id()})) {
		if ($args->{fluxobj}->flux() eq "none") {
			return "None";	
		}
		my $tbl = $self->reaction_table();
		if (!defined($tbl)) {
			return undef;	
		}
		for(my $i=0; $i < $tbl->size(); $i++) {
			$self->{_fluxes}->{$args->{fluxobj}->_id()}->{$tbl->get_row($i)->{LOAD}->[0]} = 0;
		}
		my @temp = split(/;/,$args->{fluxobj}->flux());
		for (my $i =0; $i < @temp; $i++) {
			my @temptemp = split(/:/,$temp[$i]);
			if (@temptemp >= 2) {
				$self->{_fluxes}->{$args->{fluxobj}->_id()}->{$temptemp[0]} = $temptemp[1];
			}
		}
	}
	if (!defined($self->{_fluxes}->{$args->{fluxobj}->_id()}->{$args->{id}})) {
		return "Not in model";	
	}
	return $self->{_fluxes}->{$args->{fluxobj}->_id()}->{$args->{id}};
}

=head3 get_reaction_equation
Definition:
	string = FIGMODELmodel->get_reaction_equation({-id=>string:reaction ID,-index=>integer:reaction index,-style=>NAME/ID/ABBREV});
Description:
	Returns the reaction equation formatted with the model directionality and compartment
=cut
sub get_reaction_equation {
	my ($self,$args) = @_;
	my $rxnData = $self->get_reaction_data($args);
	if (!defined($rxnData)) {
		return undef;
	}
	my $obj;
	if ($rxnData->{LOAD}->[0] =~ m/(rxn\d\d\d\d\d)/) {
		my $rxnID = $1;
		my $rxnHash = $self->figmodel()->database()->get_object_hash({type=>"reaction",attribute=>"id",-onlyIfCached=>1});
		if (defined($rxnHash)) {
			if (defined($rxnHash->{$rxnID})) {
				$obj = $rxnHash->{$rxnID}->[0];
			}
		} else {
			$obj = $self->figmodel()->database()->get_object("reaction",{id => $rxnID});
		}
	} elsif ($rxnData->{LOAD}->[0] =~ m/(bio\d\d\d\d\d)/) {
		$obj = $self->figmodel()->database()->get_object("bof",{id => $1});
	}
	if (!defined($obj)) {
		$self->error_message("get_reaction_equation:can't find reaction ".$rxnData->{LOAD}->[0]." in database!");
		return undef;	
	}
	my $cpdHash = $self->figmodel()->database()->get_object_hash({type=>"compound",attribute=>"id",-useCache=>1});
	my $equation = $obj->equation();
	my $direction = $rxnData->{DIRECTIONALITY}->[0];
	#Setting reaction directionality
	$equation =~ s/<*=>*/$direction/;
	#Adjusting reactants based on input
	if ((defined($args->{-style}) && $args->{-style} ne "ID") || $rxnData->{COMPARTMENT}->[0] ne "c") {
		$_ = $equation;
		my @reactants = /(cpd\d\d\d\d\d)/g;
		for (my $i=0; $i < @reactants; $i++) {
			my $origCpd = $reactants[$i];
			my $cpd = $origCpd;
			if (defined($args->{-style}) && $args->{-style} eq "NAME") {
				if (defined($cpdHash->{$origCpd}) && defined($cpdHash->{$origCpd}->[0]->name()) && length($cpdHash->{$origCpd}->[0]->name()) > 0) {
					$cpd = $cpdHash->{$origCpd}->[0]->name();
				}
			} elsif (defined($args->{-style}) && $args->{-style} eq "ABBREV") {
				if (defined($cpdHash->{$origCpd}) && defined($cpdHash->{$origCpd}->[0]->abbrev()) && length($cpdHash->{$origCpd}->[0]->abbrev()) > 0) {
					$cpd = $cpdHash->{$origCpd}->[0]->abbrev();
				}
			}
			if ($rxnData->{COMPARTMENT}->[0] ne "c") {
				$cpd .= "[".$rxnData->{COMPARTMENT}->[0]."]";
			}
			if ($cpd eq "all") {
				$cpd = $origCpd;
			}
			$equation =~ s/$origCpd/$cpd/g;	
		}
		$equation =~ s/\[c\]\[/[/g;
	}
	if ($equation !~ m/=/) {
		$equation = $rxnData->{DIRECTIONALITY}->[0]." ".$equation;	
	}
	return $equation;
}

=head3 load_model_table
Definition: 
	FIGMODELTable = FIGMODELmodel->load_model_table(string:table name,0/1:refresh the table));
Description: 
	Returns the table specified by the input filename. Table will be stored in a file in the model directory.
=cut
sub load_model_table {
	my ($self,$name,$refresh) = @_;
	if (defined($refresh) && $refresh == 1) {
		delete $self->{"_".$name};
	}
	if (!defined($self->{"_".$name})) {
		my $tbldef = $self->figmodel()->config($name);
		if (!defined($tbldef)) {
			return undef;
		}
		my $itemDelim = "|";
		if (defined($tbldef->{itemdelimiter}->[0])) {
			$itemDelim = $tbldef->{itemdelimiter}->[0];
			if ($itemDelim eq "SC") {
				$itemDelim = ";";	
			}
		}
		my $columnDelim = "\t";
		if (defined($tbldef->{columndelimiter}->[0])) {
			$columnDelim = $tbldef->{columndelimiter}->[0];
			if ($columnDelim eq "SC") {
				$columnDelim = ";";	
			}
		}
		my $suffix = ".tbl";
		if (defined($tbldef->{filename_suffix}->[0])) {
			$suffix = $tbldef->{filename_suffix}->[0];
		}
		my $filename = $self->directory().$name."-".$self->id().$self->selected_version().$suffix;
		if (defined($tbldef->{filename_prefix}->[0])) {
			if ($tbldef->{filename_prefix}->[0] eq "NONE") {
				$filename = $self->directory().$self->id().$self->selected_version().$suffix;
			} else {
				$filename = $self->directory().$tbldef->{filename_prefix}->[0]."-".$self->id().$self->selected_version().$suffix;
			}
		}
		if (-e $filename) {
			$self->{"_".$name} = $self->figmodel()->database()->load_table($filename,$columnDelim,$itemDelim,$tbldef->{headingline}->[0],$tbldef->{hashcolumns});
		} else {
			if (defined($tbldef->{prefix})) {
				$self->{"_".$name} = ModelSEED::FIGMODEL::FIGMODELTable->new($tbldef->{columns},$filename,$tbldef->{hashcolumns},$columnDelim,$itemDelim,join(@{$tbldef->{prefix}},"\n"));
			} else {
				$self->{"_".$name} = ModelSEED::FIGMODEL::FIGMODELTable->new($tbldef->{columns},$filename,$tbldef->{hashcolumns},$columnDelim,$itemDelim);
			}
		}
	}
	return $self->{"_".$name};
}

=head3 create_table_prototype
Definition:
	FIGMODELTable::table = FIGMODELmodel->create_table_prototype(string::table);
Description:
	Returns a empty FIGMODELTable with all the metadata associated with the input table name
=cut
sub create_table_prototype {
	my ($self,$TableName) = @_;
	#Checking if the table definition exists in the FIGMODELconfig file
	my $tbldef = $self->figmodel()->config($TableName);
	if (!defined($tbldef)) {
		$self->figmodel()->error_message("FIGMODELdatabase:create_table_prototype:Definition not found for ".$TableName);
		return undef;
	}
	#Checking that this is a database table
	if (!defined($tbldef->{tabletype}) || $tbldef->{tabletype}->[0] ne "ModelTable") {
		$self->figmodel()->error_message("FIGMODELdatabase:create_table_prototype:".$TableName." is not a model table!");
		return undef;
	}
	#Setting default values for table parameters
	my $prefix;
	if (defined($tbldef->{prefix})) {
		$prefix = join("\n",@{$self->config($TableName)->{prefix}})."\n";
	}
	my $itemDelim = "|";
	if (defined($tbldef->{itemdelimiter}->[0])) {
		$itemDelim = $tbldef->{itemdelimiter}->[0];
		if ($itemDelim eq "SC") {
			$itemDelim = ";";	
		}
	}
	my $columnDelim = "\t";
	if (defined($tbldef->{columndelimiter}->[0])) {
		$columnDelim = $tbldef->{columndelimiter}->[0];
		if ($columnDelim eq "SC") {
			$columnDelim = ";";	
		}
	}
	my $suffix = ".tbl";
	if (defined($tbldef->{filename_suffix}->[0])) {
		$suffix = $tbldef->{filename_suffix}->[0];
	}
	my $filename = $self->directory().$TableName."-".$self->id().$self->selected_version().$suffix;
	if (defined($tbldef->{filename_prefix}->[0])) {
		if ($tbldef->{filename_prefix}->[0] eq "NONE") {
			$filename = $self->directory().$self->id().$self->selected_version().$suffix;
		} else {
			$filename = $self->directory().$tbldef->{filename_prefix}->[0]."-".$self->id().$self->selected_version().$suffix;
		}
	}
	#Creating the table prototype
	my $tbl = ModelSEED::FIGMODEL::FIGMODELTable->new($tbldef->{columns},$filename,$tbldef->{hashcolumns},$columnDelim,$itemDelim,$prefix);
	return $tbl;
}

=head3 get_reaction_number
Definition:
	int = FIGMODELmodel->get_reaction_number();
Description:
	Returns the number of reactions in the model
=cut
sub get_reaction_number {
	my ($self) = @_;
	if (!defined($self->reaction_table())) {
		return 0;
	}
	return $self->reaction_table()->size();
}


=head3 essentials_table
Definition:
	FIGMODELTable = FIGMODELmodel->essentials_table();
Description:
	Returns FIGMODELTable with the essential genes for the model
=cut
sub essentials_table {
	my ($self,$clear) = @_;
	my $tbl = $self->load_model_table("ModelEssentialGenes",$clear);
	return $tbl;
}

=head3 model_history
Definition:
	FIGMODELTable = FIGMODELmodel->model_history();
Description:
	Returns FIGMODELTable with the history of model changes
=cut
sub model_history {
	my ($self,$clear) = @_;
	return $self->load_model_table("ModelHistory",$clear);
}
=head3 featureHash
Definition:
	{string:feature ID => string:data} = FIGMODELmodel->featureHash();
Description:
	Returns a hash of model related data for each gene represented in the model.
=cut
sub featureHash {
	my ($self) = @_;
	if (!defined($self->{_featurehash})) {
		my $rxnTable = $self->reaction_table();
		if (!defined($rxnTable)) {
			$self->error_message("featureHash:Could not get reaction table!");
			return undef;
		}
		for (my $i=0; $i < $rxnTable->size(); $i++) {
			my $Row = $rxnTable->get_row($i);
			if (defined($Row) && defined($Row->{"ASSOCIATED PEG"})) {
				foreach my $GeneSet (@{$Row->{"ASSOCIATED PEG"}}) {
					my $temp = $GeneSet;
					$temp =~ s/\+/|/g;
	  				$temp =~ s/\sAND\s/|/gi;
	  				$temp =~ s/\sOR\s/|/gi;
	  				$temp =~ s/[\(\)\s]//g;
	  				my @GeneList = split(/\|/,$temp);
	  				foreach my $Gene (@GeneList) {
	  					$self->{_featurehash}->{$Gene}->{reactions}->{$Row->{"LOAD"}->[0]} = 1;
	  				}
				}
	  		}
		}
		#Loading predictions
		my $esstbl = $self->essentials_table();
		my @genes = keys(%{$self->{_featurehash}});
		for (my $i=0; $i < $esstbl->size(); $i++) {
			my $row = $esstbl->get_row($i);
			if (defined($row->{MEDIA}->[0]) && defined($row->{"ESSENTIAL GENES"}->[0])) {
				for (my $j=0; $j < @genes; $j++) {
					$self->{_featurehash}->{$genes[$j]}->{essentiality}->{$row->{MEDIA}->[0]} = 0;
				}
				for (my $j=0; $j < @{$row->{"ESSENTIAL GENES"}}; $j++) {
					$self->{_featurehash}->{$row->{"ESSENTIAL GENES"}->[$j]}->{essentiality}->{$row->{MEDIA}->[0]} = 1;
				}
			}
		}
	}
	return $self->{_featurehash};
}

=head3 reaction_class_table
Definition:
	FIGMODELTable = FIGMODELmodel->reaction_class_table();
Description:
	Returns FIGMODELTable with the reaction class data, and creates the table file  if it does not exist
=cut
sub reaction_class_table {
	my ($self,$clear) = @_;
	return $self->load_model_table("ModelReactionClasses",$clear);
}

=head3 compound_class_table
Definition:
	FIGMODELTable = FIGMODELmodel->compound_class_table();
Description:
	Returns FIGMODELTable with the compound class data, and creates the table file  if it does not exist
=cut
sub compound_class_table {
	my ($self,$clear) = @_;
	return $self->load_model_table("ModelCompoundClasses",$clear);
}

=head3 get_essential_genes
Definition:
	[string::peg ID] = FIGMODELmodel->get_essential_genes(string::media condition);
Description:
	Returns an reference to an array of the predicted essential genes during growth in the input media condition
=cut
sub get_essential_genes {
	my ($self,$media) = @_;
	my $tbl = $self->essentials_table();
	my $row = $tbl->get_row_by_key($media,"MEDIA");
	if (defined($row)) {
		return $row->{"ESSENTIAL GENES"};	
	}
	return undef;
}
=head3 get_compound_data
Definition:
	{string:key=>[string]:values} = FIGMODELmodel->get_compound_data(string::compound ID);
Description:
	Returns model compound data
=cut
sub get_compound_data {
	my ($self,$compound) = @_;
	if (!defined($self->compound_table())) {
		return undef;
	}
	if ($compound =~ m/^\d+$/) {
		return $self->compound_table()->get_row($compound);
	}
	return $self->compound_table()->get_row_by_key($compound,"DATABASE");
}

=head3 get_feature_data
Definition:
	{string:key=>[string]:values} = FIGMODELmodel->get_feature_data(string::feature ID);
Description:
	Returns model feature data
=cut
sub get_feature_data {
	my ($self,$feature) = @_;
	if (!defined($self->feature_table())) {
		return undef;
	}
	if ($feature =~ m/^\d+$/) {
		return $self->feature_table()->get_row($feature);
	}
	if ($feature =~ m/(peg\.\d+)/) {
		$feature = $1;
	}
	return $self->feature_table()->get_row_by_key("fig|".$self->genome().".".$feature,"ID");
}



=head3 public
Definition:
	1/0 = FIGMODELmodel->public();
Description:
	Returns 1 if the model is public, and zero otherwise
=cut
sub public {
	my ($self) = @_;
	return $self->ppo()->public();
}

=head3 directory
Definition:
	string = FIGMODELmodel->directory();
Description:
	Returns model directory
=cut
sub directory {
	my ($self) = @_;
	if (!defined($self->{_directory})) {
		my $userdirectory = $self->owner()."/";
		my $source = $self->source();
		$self->{_directory} = $self->figmodel()->config("organism directory")->[0].$userdirectory.$self->genome()."/";
		if ($source =~ /^PM/) {
			if (length($userdirectory) == 0) {
				$self->{_directory} = $self->figmodel()->config("imported model directory")->[0].$self->id()."/";
			} else {
				$self->{_directory} = $self->figmodel()->config("organism directory")->[0].$userdirectory.$self->id()."/";
			}
		}
	}
	return $self->{_directory};
}

=head3 filename
Definition:
	string = FIGMODELmodel->filename();
Description:
	Returns model filename
=cut
sub filename {
	my ($self) = @_;

	return $self->directory().$self->id().$self->selected_version().".txt";
}

=head3 version
Definition:
	string = FIGMODELmodel->version();
Description:
	Returns the version of the model
=cut
sub version {
	my ($self) = @_;

	if (!defined($self->{_version})) {
		if (!defined($self->{_selectedversion})) {
			$self->{_version} = "V".$self->ppo()->version().".".$self->ppo()->autocompleteVersion();
		} else {
			$self->{_version} = $self->{_selectedversion};
		}
	}
	return $self->{_version};
}

=head3 selected_version
Definition:
	string = FIGMODELmodel->selected_version();
Description:
	Returns the selected version of the model
=cut
sub selected_version {
	my ($self) = @_;

	if (!defined($self->{_selectedversion})) {
		return "";
	}
	return $self->{_selectedversion};
}

=head3 modification_time
Definition:
	string = FIGMODELmodel->modification_time();
Description:
	Returns the selected version of the model
=cut
sub modification_time {
	my ($self) = @_;
	return $self->ppo()->modificationDate();
}

=head3 gene_reactions
Definition:
	string = FIGMODELmodel->gene_reactions();
Description:
	Returns the number of reactions added by the gap filling
=cut
sub gene_reactions {
	my ($self) = @_;
	return ($self->ppo()->reactions() - $self->ppo()->autoCompleteReactions() - $self->ppo()->spontaneousReactions() - $self->ppo()->gapFillReactions());
}

=head3 total_compounds
Definition:
	string = FIGMODELmodel->total_compounds();
Description:
	Returns the number of compounds in the model
=cut
sub total_compounds {
	my ($self) = @_;
	return $self->ppo()->compounds();
}

=head3 gapfilling_reactions
Definition:
	string = FIGMODELmodel->gapfilling_reactions();
Description:
	Returns the number of reactions added by the gap filling
=cut
sub gapfilling_reactions {
	my ($self) = @_;
	return ($self->ppo()->autoCompleteReactions()+$self->ppo()->gapFillReactions());
}

=head3 gapfilled_roles
Definition:
	{}:Output = FBAMODEL->gapfilled_roles->({})
	Output:{string:role name => [string]:gapfilled reactions}
Description:
	Returns a hash where the keys are gapfilled roles, and the values are arrays of gapfilled reactions associated with each role.
=cut
sub gapfilled_roles {
	my ($self) = @_;
	my $result;
	my $rxnRoleHash = $self->figmodel()->mapping()->get_role_rxn_hash();
	my $tbl = $self->reaction_table();
	if (defined($rxnRoleHash) && defined($tbl)) {
		for (my $i=0; $i < $tbl->size();$i++) {
			my $row = $tbl->get_row($i);
			if ((!defined($row->{"ASSOCIATED PEG"}) || $row->{"ASSOCIATED PEG"}->[0] =~ m/AUTO|GAP/) && defined($rxnRoleHash->{$row->{LOAD}->[0]})) {
				foreach my $role (keys(%{$rxnRoleHash->{$row->{LOAD}->[0]}})) {
					push(@{$result->{$rxnRoleHash->{$row->{LOAD}->[0]}->{$role}->name()}},$row->{LOAD}->[0]);
				}
			}
		}
	}
	return $result;
}

=head3 total_reactions
Definition:
	string = FIGMODELmodel->total_reactions();
Description:
	Returns the total number of reactions in the model
=cut
sub total_reactions {
	my ($self) = @_;
	return $self->ppo()->reactions();
}

=head3 model_genes
Definition:
	string = FIGMODELmodel->model_genes();
Description:
	Returns the number of genes mapped to one or more reactions in the model
=cut
sub model_genes {
	my ($self) = @_;
	return $self->ppo()->associatedGenes();
}

=head3 class
Definition:
	string = FIGMODELmodel->class();
Description:
	Returns the class of the model: gram positive, gram negative, other
=cut
sub class {
	my ($self) = @_;
	return $self->ppo()->cellwalltype();
}

sub autocompleteMedia {
	my ($self,$newMedia) = @_;
	if (defined($newMedia)) {
		return $self->ppo()->autoCompleteMedia($newMedia);
	}
	return $self->ppo()->autoCompleteMedia();
}

sub biomassReaction {
	my ($self,$newBiomass) = @_;
	if (!defined($newBiomass)) {
		return $self->ppo()->biomassReaction();	
	} else {
		#Figuring out what the old biomass is
		my $oldBiomass = $self->ppo()->biomassReaction();
		$self->ppo()->biomassReaction($newBiomass);
		#Changing the biomass reaction in the model file
		my $rxnTbl = $self->reaction_table();
		for (my $i=0; $i < $rxnTbl->size(); $i++) {
			my $row = $rxnTbl->get_row($i);
			if ($row->{LOAD}->[0] =~ m/^bio/) {
				$row->{LOAD}->[0] = $newBiomass;
			}
		}
		$rxnTbl->save();
		if ($newBiomass ne $oldBiomass) {
			#Figuring out if the new biomass exists
			my $handle = $self->figmodel()->database()->get_object_manager("bof");
			my $objects = $handle->get_objects({id=>$newBiomass});
			if (!defined($objects) || !defined($objects->[0])) {
				print STDERR "Could not find new biomass reaction ".$newBiomass."\n";
				return $oldBiomass;
			}
		}
		return $newBiomass;
	}
}

=head3 biomassObject
Definition:
	PPObof:biomass object = FIGMODELmodel->biomassObject();
Description:
	Returns the PPO object for the biomass reaction of the model
=cut
sub biomassObject {
	my ($self) = @_;
	if (!defined($self->{_biomassObj})) {
		$self->{_biomassObj} = $self->figmodel()->database()->get_object("bof",{id => $self->ppo()->biomassReaction()});
	}
	return $self->{_biomassObj};
}

=head3 type
Definition:
	mgmodel/model = FIGMODELmodel->type();
Description:
	Returns the type of ppo object that the current model represents
=cut
sub type {
	my ($self) = @_;
	if (!defined($self->{_type})) {
		$self->{_type} = "model";
		if ($self->source() =~ m/MGRAST/) {
			$self->{_type} = "mgmodel";
		}
	}
	return $self->{_type};
}

=head3 growth
Definition:
	double = FIGMODELmodel->growth();
Description:
=cut
sub growth {
	my ($self,$inGrowth) = @_;
	if (!defined($inGrowth)) {
		return $self->ppo()->growth();	
	} else {
		return $self->ppo()->growth($inGrowth);	
	}
}

=head3 cellwalltype
Definition:
	string = FIGMODELmodel->cellwalltype();
Description:
=cut
sub cellwalltype {
	my ($self,$inType) = @_;
	if (!defined($inType)) {
		return $self->ppo()->cellwalltype();	
	} else {
		return $self->ppo()->cellwalltype($inType);	
	}
}

=head3 autoCompleteMedia
Definition:
	string = FIGMODELmodel->autoCompleteMedia();
Description:
=cut
sub autoCompleteMedia {
	my ($self,$inType) = @_;
	if (!defined($inType)) {
		return $self->ppo()->autoCompleteMedia();	
	} else {
		return $self->ppo()->autoCompleteMedia($inType);	
	}
}

=head3 noGrowthCompounds
Definition:
	string = FIGMODELmodel->noGrowthCompounds();
Description:
=cut
sub noGrowthCompounds {
	my ($self,$inCompounds) = @_;
	if (!defined($inCompounds)) {
		return $self->ppo()->noGrowthCompounds();	
	} else {
		return $self->ppo()->noGrowthCompounds($inCompounds);	
	}
}

=head3 taxonomy
Definition:
	string = FIGMODELmodel->taxonomy();
Description:
	Returns model taxonomy or biome if this is an metagenome model
=cut
sub taxonomy {
	my ($self) = @_;
	return $self->genomeObj()->taxonomy();
}

=head3 genome_size
Definition:
	string = FIGMODELmodel->genome_size();
Description:
	Returns size of the modeled genome in KB
=cut
sub genome_size {
	my ($self) = @_;
	return $self->genomeObj()->size();
}

=head3 genome_genes
Definition:
	string = FIGMODELmodel->genome_genes();
Description:
	Returns the number of genes in the modeled genome
=cut
sub genome_genes {
	my ($self) = @_;
	return $self->genomeObj()->totalGene();
}

=head3 update_stats_for_gap_filling
Definition:
	{string => [string]} = FIGMODELmodel->update_stats_for_gap_filling(int::gapfill time);
Description:
=cut
sub update_stats_for_gap_filling {
	my ($self,$gapfilltime) = @_;
	$self->ppo()->autoCompleteTime($gapfilltime);
	$self->ppo()->autocompleteDate(time());
	$self->ppo()->modificationDate(time());
	my $version = $self->ppo()->autocompleteVersion();
	$self->ppo()->autocompleteVersion($version+1);
}

=head3 update_stats_for_build
Definition:
	{string => [string]} = FIGMODELmodel->update_stats_for_build();
Description:
=cut
sub update_stats_for_build {
	my ($self) = @_;
	$self->ppo()->builtDate(time());
	$self->ppo()->modificationDate(time());
	my $version = $self->ppo()->version();
	$self->ppo()->version($version+1);
}

=head3 update_model_stats
Definition:
	FIGMODELmodel->update_model_stats();
Description:
=cut
sub update_model_stats {
	my ($self) = @_;
	#Getting reaction table
	my $rxntbl = $self->reaction_table();
	if (!defined($rxntbl)) {
		die $self->error_message("update_model_stats:Could not load reaction list!");
	}
	my $cpdtbl = $self->compound_table();
	#Calculating all necessary stats
	my %GeneHash;
	my %NonpegHash;
	my %CompoundHash;
	my $spontaneousReactions = 0;
	my $gapFillReactions = 0;
	my $biologReactions = 0;
	my $transporters = 0;
	my $autoCompleteReactions = 0;
	my $associatedSubsystemGenes = 0;
	for (my $i=0; $i < $rxntbl->size(); $i++) {
		my $Row = $rxntbl->get_row($i);
		if (defined($Row) && defined($Row->{"ASSOCIATED PEG"})) {
			my $ReactionRow = $self->figmodel()->get_reaction($Row->{"LOAD"}->[0]);
			if (defined($ReactionRow->{"EQUATION"}->[0])) {
				#Checking for extracellular metabolites which indicate that this is a transporter
				if ($ReactionRow->{"EQUATION"}->[0] =~ m/\[e\]/) {
					$transporters++;
				}
			}
			#Identifying spontaneous/biolog/gapfilling/gene associated reactions
			if ($Row->{"ASSOCIATED PEG"}->[0] =~ m/BIOLOG/i) {
				$biologReactions++;
			} elsif ($Row->{"ASSOCIATED PEG"}->[0] =~ m/GROW/i) {
				$gapFillReactions++;
			} elsif ($Row->{"ASSOCIATED PEG"}->[0] =~ m/SPONTANEOUS/i) {
				$spontaneousReactions++;
			} elsif ($Row->{"ASSOCIATED PEG"}->[0] =~ m/GAP/ || $Row->{"ASSOCIATED PEG"}->[0] =~ m/UNIVERSAL/i || $Row->{"ASSOCIATED PEG"}->[0] =~ m/UNKNOWN/i || $Row->{"ASSOCIATED PEG"}->[0] =~ m/AUTOCOMPLETION/i) {
				$autoCompleteReactions++;
			} else {
				foreach my $GeneSet (@{$Row->{"ASSOCIATED PEG"}}) {
					$_ = $GeneSet;
					my @GeneList = /(peg\.\d+)/g;
					foreach my $Gene (@GeneList) {
						if ($Gene =~ m/(peg\.\d+)/) {
							$GeneHash{$1} = 1;
						} else {
							$NonpegHash{$Gene} = 1;
						}
					}
				}
			}
		}
	}
	my @genes = keys(%GeneHash);
	my @othergenes = keys(%NonpegHash);
	#Setting the reaction count
	$self->ppo()->reactions($rxntbl->size());
	#Setting the metabolite count
	$self->ppo()->compounds($cpdtbl->size());
	#Setting the gene count
	my $geneCount = @genes + @othergenes;
	$self->ppo()->associatedGenes($geneCount);
	#Setting remaining stats
	$self->ppo()->spontaneousReactions($spontaneousReactions);
	$self->ppo()->gapFillReactions($gapFillReactions);
	$self->ppo()->biologReactions($biologReactions);
	$self->ppo()->transporters($transporters);
	$self->ppo()->autoCompleteReactions($autoCompleteReactions);
	$self->ppo()->associatedSubsystemGenes($associatedSubsystemGenes);
	#Setting the model class
	my $class = "";
	for (my $i=0; $i < @{$self->figmodel()->config("class list")}; $i++) {
		if (defined($self->figmodel()->config($self->figmodel()->config("class list")->[$i]))) {
			if (defined($self->figmodel()->config($self->figmodel()->config("class list")->[$i])->{$self->id()})) {
				$class = $self->figmodel()->config("class list")->[$i];
				last;
			}
			if ($class eq "" && defined($self->figmodel()->config($self->figmodel()->config("class list")->[$i])->{$self->genome()})) {
				$class = $self->figmodel()->config("class list")->[$i];
			}
		}
	}
	if ($class eq "" && defined($self->genomeObj()->genome_stats())) {
		$class = $self->genomeObj()->genome_stats()->class();
	}
	if ($class eq "") {
		$class = "unknown";	
	}
	$self->ppo()->cellwalltype($class);
}

=head3 printInactiveReactions
Definition:
	{error => string} = FIGMODELmodel->printInactiveReactions({
		filename => string,
	});
Description:
=cut
sub printInactiveReactions {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["filename"],{});
	if (defined($args->{error})) {return $self->error_message({function => "printInactiveReactions",args => $args});}
	my $obj = $self->figmodel()->database()->get_object("mdlfva",{MODEL=>$self->id(),MEDIA=>"Complete",parameters=>"NG;DR:bio00001;"});
    #Loading priority list
    my $priorities = $self->figmodel()->database()->load_single_column_file($self->figmodel()->config("reaction priority list")->[0],"\t");
    print "test\n";
    if (defined($obj)) {
    	my @rxnList = split(/;/,$obj->inactive().$obj->dead());
		my $hash;
		for(my $j=0; $j < @rxnList; $j++) {
			if (length($rxnList[$j]) > 0) {
				$hash->{$rxnList[$j]} = 0;
			}
		}
		if (defined($hash->{$self->ppo()->biomassReaction()})) {
			delete 	$hash->{$self->ppo()->biomassReaction()};
		}
		my $finalList;
		for(my $j=0; $j < @{$priorities}; $j++) {
			if (defined($hash->{$priorities->[$j]})) {
				push(@{$finalList},$priorities->[$j]);
				$hash->{$priorities->[$j]} = 1;
			}
		}
		foreach my $rxn (keys(%{$hash})) {
			if ($hash->{$rxn} == 0) {
				push(@{$finalList},$rxn);
				$hash->{$rxn} = 1;
			}
		}
		push(@{$finalList},$self->ppo()->biomassReaction());
		print $args->{filename}."\n";
		$self->figmodel()->database()->print_array_to_file($args->{filename},$finalList);
    }
}

=head3 completeGapfilling
Definition:
	{error => string} = FIGMODELmodel->completeGapfilling({
		gapfillCoefficientsFile => "NONE",
		inactiveReactionBonus => 0.1,
		drainBiomass => "bio00001",
		media => "Complete"
	});
Description:
=cut
sub completeGapfilling {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{solutionFile=>undef,printLPFileOnly=>0,doNotClear => 0,runReactionActivityCheck => 1,gapfillCoefficientsFile => "NONE",inactiveReactionBonus => 0.1,drnRxn => ["bio00001"],media => "Complete"});
	if (defined($args->{error})) {return $self->error_message({function => "completeGapfilling",args => $args});}
	#Creating fba object and output directory
	my $StartTime = time();
	my $fbaObj = $self->fba();
	#Removing the previous gapfilling solution
	if ($args->{doNotClear} != 1) {
		my $ModelTable = $self->reaction_table();
		for (my $i=0; $i < $ModelTable->size(); $i++) {
			$ModelTable->get_row($i)->{"DIRECTIONALITY"}->[0] = $self->figmodel()->reversibility_of_reaction($ModelTable->get_row($i)->{"LOAD"}->[0]);
			if (!defined($ModelTable->get_row($i)->{"ASSOCIATED PEG"}->[0]) || $ModelTable->get_row($i)->{"ASSOCIATED PEG"}->[0] eq "AUTOCOMPLETION" || $ModelTable->get_row($i)->{"ASSOCIATED PEG"}->[0] eq "GAP FILLING" || $ModelTable->get_row($i)->{"ASSOCIATED PEG"}->[0] =~ m/BIOLOG/ || $ModelTable->get_row($i)->{"ASSOCIATED PEG"}->[0] =~ m/GROWMATCH/) {
				$ModelTable->delete_row($i);
				$i--;
			}
		}
		$ModelTable->save();
		$self->reaction_table(1);
	}
	if (!defined($args->{solutionFile})) {
		$self->set_status(1,"Auto completion running");
		#Setting up study
		my $results = $self->fbaFVA($self->figmodel()->copyMergeHash([$args,{growth=>"none",drnRxn => ["bio00001"]}]));
		$fbaObj->makeOutputDirectory();
		$self->printInactiveReactions({filename=>$fbaObj->directory()."/InactiveModelReactions.txt"});
		$args->{filename} = $fbaObj->filename();
		$fbaObj->setCompleteGapfillingStudy($args);
		$fbaObj->runFBA();
		if ($args->{printLPFileOnly} == 1) {
			if (!-e $fbaObj->directory()."/CurrentProblem.lp") {return $self->error_message({message=>"Could not find LP file!",function => "completeGapfilling",args => $args});}
			system("cp ".$fbaObj->directory()."/CurrentProblem.lp ".$self->directory()."completeGapFill.lp");
			$self->set_status(1,"Gapfilling file printed");
			return $self->figmodel()->success();
		}
	} 
	#Backing up the old solution if one exists
	if (-e $self->directory()."/CompleteGapfillingOutput.txt") {
		my $oldFile = $self->figmodel()->database()->load_single_column_file($self->directory()."/CompleteGapfillingOutput.txt","");
		if (@{$oldFile} >= 2) {
			$self->figmodel()->database()->print_array_to_file($self->directory()."/CompleteGapfillingOutput.bkup",$oldFile,1);
		}
	}
	#Copying the new solution to the output file in the model directory
	if (defined($args->{solutionFile})) {
		my $output = ["Target reaction	Gapfilled reactions	Activated reactions	Count	Time"];
		my $input = $self->figmodel()->database()->load_single_column_file($args->{solutionFile},"");
		my @dataArray = split(/\t/,$input->[0]);
    	my @gapFilledArray = split(/,/,$dataArray[1]);
    	my @activated = split(/,/,$dataArray[2]);	
    	my $fixed;
    	my $repaired;
    	my $target = $dataArray[0];
    	if (!defined($target) || length($target) == 0) {
    		$target = $self->ppo()->biomassReaction();
    	}
    	for (my $i=0;$i < @gapFilledArray; $i++) {
    		if ($gapFilledArray[$i] =~ m/RFU_(.+)$/) {
    			push(@{$fixed},"-".$1);
    		} elsif ($gapFilledArray[$i] =~ m/FFU_(.+)$/) {
    			push(@{$fixed},"+".$1);
    		}
    	}
    	for (my $i=0;$i < @activated; $i++) {
    		if ($activated[$i] =~ m/RFU_(.+)$/) {
    			push(@{$repaired},"-".$1);
    		} elsif ($activated[$i] =~ m/FFU_(.+)$/) {
    			push(@{$repaired},"+".$1);
    		}
    	}
    	push(@{$output},$target."\t".join(";",@{$fixed})."\t".join(";",@{$repaired})."\t0\t0");
    	$self->figmodel()->database()->print_array_to_file($self->directory()."CompleteGapfillingOutput.txt",$output);
	} else {
		system("cp ".$fbaObj->directory()."/CompleteGapfillingOutput.txt ".$self->directory()."CompleteGapfillingOutput.txt");
	}
	my $results = $fbaObj->parseCompleteGapfillingStudy({solutionFile=>$self->directory()."CompleteGapfillingOutput.txt"});
	if (defined($results->{error})) {return $self->error_message({message => $results->{error},function => "completeGapfilling",args => $args});}
	#Integrating results into model file
	my $solutionHash;
	foreach my $rxn (keys(%{$results})) {
		if (defined($results->{$rxn}->{gapfilled}->[0])) {
			for (my $i=0; $i < @{$results->{$rxn}->{gapfilled}}; $i++) {
				if ($results->{$rxn}->{gapfilled}->[$i] =~ m/(.)(rxn\d+)/) {
					my $gapRxn = $2;
					my $gapSign = $1;
					my $sign = "=>";
					if ($gapSign eq "-") {
						$sign = "<=";
					}
					if (defined($solutionHash->{$gapRxn}->{sign}) && $solutionHash->{$gapRxn}->{sign} ne $sign) {
						$sign = "<=>";
					}
					$solutionHash->{$gapRxn}->{sign} = $sign;
					push(@{$solutionHash->{$gapRxn}->{target}},$rxn);
					if (defined($results->{$rxn}->{repaired}->[0])) {
						for (my $j=0; $j < @{$results->{$rxn}->{repaired}}; $j++) {
							if ($results->{$rxn}->{repaired}->[$j] =~ m/(.)(rxn\d+)/) {
								$solutionHash->{$gapRxn}->{repaired}->{$2} = 1;
							}
						}
					}
				}
			}
		}
	}
	#Adjusting model based on gapfilling solution
	my $rxnTbl = $self->reaction_table(1);
	foreach my $rxn (keys(%{$solutionHash})) {
		my $rev = $self->figmodel()->reversibility_of_reaction($rxn);
		if ($solutionHash->{$rxn}->{sign} ne $rev) {
			$solutionHash->{$rxn}->{sign} = "<=>";
		}
		my $target = "None";
		my $repair = "None";
		if (defined($solutionHash->{$rxn}->{target})) {
			$target = join(", ",@{$solutionHash->{$rxn}->{target}});
		}
		if (defined($solutionHash->{$rxn}->{repaired})) {
			$repair = join(", ",keys(%{$solutionHash->{$rxn}->{repaired}}));
		}
		my $row = $rxnTbl->get_row_by_key($rxn,"LOAD");
		if (!defined($row)) {
			$rxnTbl->add_row({SUBSYSTEM => ["NONE"],CONFIDENCE => [4],REFERENCE => ["NONE"],NOTES => [],LOAD => [$rxn],DIRECTIONALITY => [$solutionHash->{$rxn}->{sign}],COMPARTMENT => ["c"],"ASSOCIATED PEG" => ["AUTOCOMPLETION"]});
		} else {
			$row->{NOTES}->[0] = "Switched from ".$row->{DIRECTIONALITY}->[0];
			$row->{DIRECTIONALITY}->[0] = "<=>";
		}
	}
	$rxnTbl->save();
	my $ElapsedTime = time() - $StartTime;
	if ($args->{doNotClear} != 1) {
		system($self->figmodel()->config("Model driver executable")->[0]." \"updatestatsforgapfilling?".$self->id()."?".$ElapsedTime."\"");
	}
	#Queueing up model change and gapfilling dependancy functions
	system($self->figmodel()->config("Model driver executable")->[0]." \"setmodelstatus?".$self->id()."?1?Autocompletion___successfully___finished\"");
	system($self->figmodel()->config("Model driver executable")->[0]." \"processmodel?".$self->id()."\"");
	return $self->figmodel()->success();
}

=head3 GapFillModel
Definition:
	(success/fail) = FIGMODELmodel->GapFillModel();
Description:
	This function performs an optimization to identify the minimal set of reactions that must be added to a model in order for biomass to be produced by the biomass reaction in the model.
	Before running the gap filling, the existing model is backup in the same directory with the current version numbers appended.
	If the model has been gap filled previously, the previous gap filling reactions are removed prior to running the gap filling again.
=cut
sub GapFillModel {
	my ($self,$donotclear,$createLPFileOnly, $Media) = @_;

	#Setting status of model to gap filling
	my $OrganismID = $self->genome();
	$self->set_status(1,"Auto completion running");
	my $UniqueFilename = $self->figmodel()->filename();
	my $StartTime = time();
	
	#Reading original reaction table
	my $OriginalRxn = $self->reaction_table();
	#Clearing the table
	$self->reaction_table(1);
	#Removing any gapfilling reactions that may be currently present in the model
	if (!defined($donotclear) || $donotclear != 1) {
		my $ModelTable = $self->reaction_table();
		for (my $i=0; $i < $ModelTable->size(); $i++) {
			$ModelTable->get_row($i)->{"DIRECTIONALITY"}->[0] = $self->figmodel()->reversibility_of_reaction($ModelTable->get_row($i)->{"LOAD"}->[0]);
			if (!defined($ModelTable->get_row($i)->{"ASSOCIATED PEG"}->[0]) || $ModelTable->get_row($i)->{"ASSOCIATED PEG"}->[0] eq "AUTOCOMPLETION" || $ModelTable->get_row($i)->{"ASSOCIATED PEG"}->[0] eq "GAP FILLING" || $ModelTable->get_row($i)->{"ASSOCIATED PEG"}->[0] =~ m/BIOLOG/ || $ModelTable->get_row($i)->{"ASSOCIATED PEG"}->[0] =~ m/GROWMATCH/) {
				$ModelTable->delete_row($i);
				$i--;
			}
		}
		$ModelTable->save();
	}

	#Calling the MFAToolkit to run the gap filling optimization
    if(!defined($Media)) {
        $Media = $self->autocompleteMedia();
    }
	my $lpFileOnlyParameter = 0;
	if (defined($createLPFileOnly) && $createLPFileOnly == 1) {
		$lpFileOnlyParameter = 1;
	}
	if ($Media eq "Complete") {
		system($self->figmodel()->GenerateMFAToolkitCommandLineCall($UniqueFilename,$self->id(),undef,["GapFilling"],{
			"Constrain objective to this fraction of the optimal value"=>"0.001",
			"Default min drain flux"=>"-10000",
			"Default max drain flux"=>"10000",
			"MFASolver"=>"CPLEX",
			"Allowable unbalanced reactions"=>$self->config("acceptable unbalanced reactions")->[0],
			"print lp files rather than solve" => $lpFileOnlyParameter,
			"dissapproved compartments"=>$self->config("diapprovied compartments")->[0],
			"Reactions to knockout" => $self->config("permanently knocked out reactions")->[0]
		},"GapFill".$self->id().".log",undef));
	} else {
		#Loading media, changing bounds, saving media as a test media
		my $MediaTable = ModelSEED::FIGMODEL::FIGMODELTable::load_table($self->config("Media directory")->[0].$Media.".txt",";","",0,["VarName"]);
		for (my $i=0; $i < $MediaTable->size(); $i++) {
			if ($MediaTable->get_row($i)->{"Min"}->[0] < 0) {
				$MediaTable->get_row($i)->{"Min"}->[0] = -10000;
			}
			if ($MediaTable->get_row($i)->{"Max"}->[0] > 0) {
				$MediaTable->get_row($i)->{"Max"}->[0] = 10000;
			}
		}
		$MediaTable->save($self->config("Media directory")->[0].$UniqueFilename."TestMedia.txt");
		system($self->figmodel()->GenerateMFAToolkitCommandLineCall($UniqueFilename,$self->id(),$UniqueFilename."TestMedia",["GapFilling"],{"MFASolver"=>"CPLEX","Allowable unbalanced reactions"=>$self->config("acceptable unbalanced reactions")->[0],"print lp files rather than solve" => $lpFileOnlyParameter,"Default max drain flux" => 0,"dissapproved compartments"=>$self->config("diapprovied compartments")->[0],"Reactions to knockout" => $self->config("permanently knocked out reactions")->[0]},"GapFill".$self->id().".log",undef));
		unlink($self->config("Media directory")->[0].$UniqueFilename."TestMedia.txt");
	}
	if (defined($createLPFileOnly) && $createLPFileOnly == 1) {
		if (-e $self->figmodel()->config("MFAToolkit output directory")->[0].$UniqueFilename."/MFAOutput/LPFiles/0.lp") {;
			system("cp ".$self->figmodel()->config("MFAToolkit output directory")->[0].$UniqueFilename."/MFAOutput/LPFiles/0.lp ".$self->figmodel()->config("LP file directory")->[0]."GapFilling-".$self->id().".lp");
			return $self->figmodel()->success();
		}
		return $self->figmodel()->fail();
	}

	#Looking for gapfilling report
	if (!-e $self->config("MFAToolkit output directory")->[0].$UniqueFilename."/GapFillingReport.txt") {
		$self->error_message("GapFillModel: no gapfilling solution found!");
		system($self->figmodel()->config("Model driver executable")->[0]." \"setmodelstatus?".$self->id()."?1?Autocompletion___failed___to___find___solution\"");
		return $self->figmodel()->fail();
	}
	#Loading gapfilling report
	my $gapTbl = ModelSEED::FIGMODEL::FIGMODELTable::load_table($self->config("MFAToolkit output directory")->[0].$UniqueFilename."/GapFillingReport.txt",";","|",0,undef);
	#Copying gapfilling report to model directory
	system("cp ".$self->config("MFAToolkit output directory")->[0].$UniqueFilename."/GapFillingReport.txt ".$self->directory()."GapFillingReport.txt");
	#Adding gapfilling solution to model
	for (my $i=0; $i < $gapTbl->size(); $i++) {
		my $row = $gapTbl->get_row($i);
		if (defined($row->{Solutions}->[0])) {
			my $rxnTbl = $self->reaction_table();
			my $solution = $row->{Solutions}->[0];
			my @reactions = split(/,/,$solution);
			for (my $i=0; $i < @reactions; $i++) {
				if ($reactions[$i] =~ m/([\+\-])(rxn\d\d\d\d\d)/) {
					my $sign = $1;
					my $reaction = $2;
					my $rxnRow = $rxnTbl->get_row_by_key($reaction,"LOAD");
					if (defined($rxnRow)) {
						$rxnRow->{"DIRECTIONALITY"}->[0] = "<=>";
					} else {
						my $direction = $self->figmodel()->reversibility_of_reaction($reaction);
						if ($direction ne "<=>") {
							if ($sign eq "-" && $direction eq "=>") {
								 $direction = "<=>";
							} elsif ($sign eq "+" && $direction eq "<=") {
								$direction = "<=>";
							}
						}
						$rxnTbl->add_row({LOAD => [$reaction],DIRECTIONALITY => [$direction],COMPARTMENT => ["c"],"ASSOCIATED PEG" => ["AUTOCOMPLETION"]});
					}
					
					
				}
			}
			$rxnTbl->save();
			last;
		}
	}
	$OriginalRxn->save($self->directory()."OriginalModel-".$self->id()."-".$UniqueFilename.".txt");
	my $ElapsedTime = time() - $StartTime;
	if (!defined($donotclear) || $donotclear != 1) {
		system($self->figmodel()->config("Model driver executable")->[0]." \"updatestatsforgapfilling?".$self->id()."?".$ElapsedTime."\"");
	}
	#Queueing up model change and gapfilling dependancy functions
	system($self->figmodel()->config("Model driver executable")->[0]." \"calculatemodelchanges?".$self->id()."?".$UniqueFilename."?Autocompletion\"");
	system($self->figmodel()->config("Model driver executable")->[0]." \"getgapfillingdependancy?".$self->id()."\"");
	system($self->figmodel()->config("Model driver executable")->[0]." \"setmodelstatus?".$self->id()."?1?Autocompletion___successfully___finished\"");
	system($self->figmodel()->config("Model driver executable")->[0]." \"processmodel?".$self->id()."\"");
	return $self->figmodel()->success();
}

=head3 processModel
Definition:
	FIGMODELmodel->processModel();
Description:
=cut
sub processModel {
	my ($self) = @_;
    if (-e $self->directory()) {
        mkdir $self->directory();
    }
	if (-e $self->directory()."ReactionClassification-".$self->id().".tbl") {
		system("rm ".$self->directory()."ReactionClassification-".$self->id().".tbl");
	}
	if (-e $self->directory()."CompoundClassification-".$self->id().".tbl") {
		system("rm ".$self->directory()."CompoundClassification-".$self->id().".tbl");
	}
	if (-e $self->directory()."EssentialGenes-".$self->id().".tbl") {
		system("rm ".$self->directory()."EssentialGenes-".$self->id().".tbl");
	}
	if (-e $self->directory()."FBA-".$self->id().".lp") {
		system("rm ".$self->directory()."FBA-".$self->id().".lp");
	}
	if (-e $self->directory()."FBA-".$self->id().".key") {
		system("rm ".$self->directory()."FBA-".$self->id().".key");
	}
	if (-e $self->directory().$self->id().".xml") {
		system("rm ".$self->directory().$self->id().".xml");
	}
	if (-e $self->directory().$self->id().".lp") {
		system("rm ".$self->directory().$self->id().".lp");
	}
	if (-e $self->directory()."ReactionTbl-".$self->id().".tbl") {
		system("rm ".$self->directory()."ReactionTbl-".$self->id().".tbl");
	}
	if (-e $self->directory()."ReactionTbl-".$self->id().".txt") {
		system("rm ".$self->directory()."ReactionTbl-".$self->id().".txt");
	}
    unless(-e $self->directory().$self->id().".txt") { 
        # if the base file doesn't exist try to generate it from the database
        $self->generateBaseModelFileFromDatabase();
    }
    $self->create_model_rights();
    $self->transfer_rights_to_biomass();
	$self->update_model_stats();
	$self->PrintSBMLFile();
	$self->PrintModelLPFile();
	$self->PrintModelLPFile(1);
	$self->PrintModelSimpleReactionTable();
	$self->run_default_model_predictions();
}

=head3 load_scip_gapfill_results
Definition:
	FIGMODELmodel->load_scip_gapfill_results(string:filename);
Description:
	
=cut

sub load_scip_gapfill_results {
	my ($self,$filename) = @_;
	my $time = 0;
	my $gap = 0;
	my $objective = 0;
	my $start = 0;
	my $ReactionList;
	my $DirectionList;
	my $fileLines = $self->figmodel()->database()->load_single_column_file($filename);
	for (my $i=0; $i < @{$fileLines}; $i++) {
		if ($fileLines->[$i] =~ m/^\s*(\d+)m\|.+\s(.+)%/) {
			$time = 60*$1;
			$gap = $2;
		} elsif ($fileLines->[$i] =~ m/^\s*(\d+)s\|.+\s(.+)%/) {
			$time = $1;
			$gap = $2;
		} elsif ($fileLines->[$i] =~ m/solving\swas\sinterrupted/ && $gap eq "0") {
			$gap = 1;
		} elsif ($fileLines->[$i] =~ m/^Solving\sTime\s\(sec\)\s:\s*(\S+)/) {
			$time = $1;
		} elsif ($fileLines->[$i] =~ m/^Gap.+:\s*([\S]+)\s*\%/) {	
			$gap = $1;
		} elsif ($fileLines->[$i] =~ m/^objective\svalue:\s*([\S]+)/) {
			$objective = $1;
			$start = 1;
		} elsif ($start == 1 && $fileLines->[$i] =~ m/\(obj:([\S]+)\)/) {
			my $coef = $1;
			if ($coef ne "0") {
				my $ID = "";
				my $Sign = "<=>";
				if ($fileLines->[$i] =~ m/^FFU_(rxn\d\d\d\d\d)/) {
					$Sign = "=>";
					$ID = $1;
				} elsif ($fileLines->[$i] =~ m/^RFU_(rxn\d\d\d\d\d)/) {
					$Sign = "<=";
					$ID = $1;
				}
				if ($ID ne "") {
					if ($self->figmodel()->reversibility_of_reaction($ID) ne $Sign) {
						$Sign = "<=>";
					}
					push(@{$DirectionList},$Sign);
					push(@{$ReactionList},$ID);
				}
			}
		}
	}
	$self->ppo()->autocompletionDualityGap($gap);
	$self->ppo()->autocompletionObjective($objective);
	$self->ppo()->autoCompleteTime($time);
	if (defined($ReactionList) && @{$ReactionList} > 0) {
		my $OriginalRxn = $self->reaction_table();
		$self->figmodel()->IntegrateGrowMatchSolution($self->id(),undef,$ReactionList,$DirectionList,"AUTOCOMPLETION",0,1);
		#Updating model stats with gap filling results
		$self->reaction_table(1);
		$self->calculate_model_changes($OriginalRxn,"AUTOCOMPLETION");
		#Determining why each gap filling reaction was added
		$self->figmodel()->IdentifyDependancyOfGapFillingReactions($self->id(),$self->autocompleteMedia());
		if ($self->id() !~ m/MGRast/) {
			$self->update_stats_for_gap_filling($time);
		} else {
			$self->update_model_stats();
		}
		#Printing the updated SBML file
		$self->PrintSBMLFile();
		$self->PrintModelLPFile($self->id());
		$self->set_status(1,"Auto completion successfully finished");
		$self->run_default_model_predictions();
		return $self->figmodel()->success();
	} else {
		$self->set_status(1,"No autocompletion soluion found. Autocompletion time extended.");
	}
	return $self->figmodel()->fail();	
}

=head3 compare_reaction_tables
Definition:
	FIGMODELTable:changes = FIGMODELFIGMODELmodel->compare_reaction_tables({changeTbl => FIGMODELTable:existing change table,
																			changeTblFile => string:filename for existing change table,
																			compareTbl => FIGMODELTable:table to compare against,
																			note => string:modification note});
Description:
=cut
sub compare_two_reaction_tables {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["compareTbl"],{changeTbl => undef,changeTblFile => undef,note => "NONE"});
	if (defined($args->{error})) {return {error => $args->{error}};}
	#Loading the existing change table if provided, otherwise creating new change table
	my $changeTbl;
	if (defined($args->{changeTbl})) {
		$changeTbl = $args->{changeTbl};
	} elsif (defined($args->{changeTblFile})) {
		$changeTbl = $self->figmodel()->database()->load_table($self->directory().$args->{changeTblFile},"\t","|",0,["Reaction","ChangeType"]);
	} else {
		$changeTbl = ModelSEED::FIGMODEL::FIGMODELTable->new(["Reaction","Direction","Compartment","Genes","ChangeType","Note","ChangeTime"],"Temp.txt",["Reaction","ChangeType"],"\t","|",undef);
	}
	my $rxnTbl = $self->reaction_table();
	my $cmpTbl = $args->{compareTbl};
	for (my $i=0; $i < $rxnTbl->size(); $i++) {
		my $row = $rxnTbl->get_row($i);
		my $orgRow = $cmpTbl->get_row_by_key($row->{LOAD}->[0],"LOAD");
		if (!defined($orgRow)) {
			$changeTbl->add_row({Reaction => $row->{LOAD},Direction => $row->{DIRECTIONALITY},Compartment => $row->{COMPARTMENT},Genes => $row->{"ASSOCIATED PEG"},ChangeType => ["Reaction added"],Note => [$args->{note}],ChangeTime => time()});
		} else {
			if ($row->{DIRECTIONALITY}->[0] ne $orgRow->{DIRECTIONALITY}->[0]) {
				$changeTbl->add_row({Reaction => $row->{LOAD},Direction => $row->{DIRECTIONALITY},Compartment => $row->{COMPARTMENT},Genes => $row->{"ASSOCIATED PEG"},ChangeType => ["Directionality change(".$orgRow->{DIRECTIONALITY}->[0].")"],Note => [$args->{note}],ChangeTime => time()});
			}
			if ($row->{COMPARTMENT}->[0] ne $orgRow->{COMPARTMENT}->[0]) {
				$changeTbl->add_row({Reaction => $row->{LOAD},Direction => $row->{DIRECTIONALITY},Compartment => $row->{COMPARTMENT},Genes => $row->{"ASSOCIATED PEG"},ChangeType => ["Compartment change(".$orgRow->{COMPARTMENT}->[0].")"],Note => [$args->{note}],ChangeTime => time()});
			}
			if ($row->{COMPARTMENT}->[0] ne $orgRow->{COMPARTMENT}->[0]) {
				$changeTbl->add_row({Reaction => $row->{LOAD},Direction => $row->{DIRECTIONALITY},Compartment => $row->{COMPARTMENT},Genes => $row->{"ASSOCIATED PEG"},ChangeType => ["Compartment change(".$orgRow->{COMPARTMENT}->[0].")"],Note => [$args->{note}],ChangeTime => time()});
			}
			if (defined($row->{"ASSOCIATED PEG"})) {
				for (my $j=0; $j < @{$row->{"ASSOCIATED PEG"}}; $j++) {
					my $match = 0;
					if (defined($orgRow->{"ASSOCIATED PEG"})) {
						for (my $k=0; $k < @{$orgRow->{"ASSOCIATED PEG"}}; $k++) {
							if ($row->{"ASSOCIATED PEG"}->[$j] eq $orgRow->{"ASSOCIATED PEG"}->[$k]) {
								$match = 1;	
							}
						}
					}
					if ($match == 0) {
						$changeTbl->add_row({Reaction => $row->{LOAD},Direction => $row->{DIRECTIONALITY},Compartment => $row->{COMPARTMENT},Genes => $row->{"ASSOCIATED PEG"},ChangeType => ["GPR added(".$row->{"ASSOCIATED PEG"}->[$j].")"],Note => [$args->{note}],ChangeTime => time()});
					}
				}
			}
			if (defined($orgRow->{"ASSOCIATED PEG"})) {
				for (my $k=0; $k < @{$orgRow->{"ASSOCIATED PEG"}}; $k++) {
					my $match = 0;
					if (defined($row->{"ASSOCIATED PEG"})) {
						for (my $j=0; $j < @{$row->{"ASSOCIATED PEG"}}; $j++) {
							if ($row->{"ASSOCIATED PEG"}->[$j] eq $orgRow->{"ASSOCIATED PEG"}->[$k]) {
								$match = 1;
							}
						}
					}
					if ($match == 0) {
						$changeTbl->add_row({Reaction => $row->{LOAD},Direction => $row->{DIRECTIONALITY},Compartment => $row->{COMPARTMENT},Genes => $row->{"ASSOCIATED PEG"},ChangeType => ["GPR removed(".$orgRow->{"ASSOCIATED PEG"}->[$k].")"],Note => [$args->{note}],ChangeTime => time()});
					}
				}
			}
		}
	}
	#Looking for removed reactions
	for (my $i=0; $i < $cmpTbl->size(); $i++) {
		my $row = $cmpTbl->get_row($i);
		my $orgRow = $rxnTbl->get_row_by_key($row->{LOAD}->[0],"LOAD");
		if (!defined($orgRow)) {
			$changeTbl->add_row({Reaction => $row->{LOAD},Direction => $row->{DIRECTIONALITY},Compartment => $row->{COMPARTMENT},Genes => $row->{"ASSOCIATED PEG"},ChangeType => ["Reaction removed"],Note => [$args->{note}],ChangeTime => time()});
		}
	}
	return $changeTbl;
}

=head3 calculate_model_changes
Definition:
	FIGMODELmodel->calculate_model_changes(FIGMODELTable:original reaction table,string:modification cause);
Description:
	
=cut

sub calculate_model_changes {
	my ($self,$originalReactions,$cause,$tbl,$version,$filename) = @_;
	my $modTime = time();
	if (!defined($version)) {
		$version = $self->selected_version();
	}
	if (defined($filename) && !defined($originalReactions) && -e $self->directory()."OriginalModel-".$self->id()."-".$filename.".txt") {
		$originalReactions = $self->figmodel()->database()->load_table($self->directory()."OriginalModel-".$self->id()."-".$filename.".txt",";","|",1,["LOAD","ASSOCIATED PEG"]);
	}
	my $user = $self->figmodel()->user();
	#Creating model history transaction
	my $mdlHistTransObj = $self->figmodel()->database()->create_object("mdlhisttrans",{version=>$version,cause=>$cause,user=>$user,modificationDate=>$modTime,MODEL=>$self->id()});
	#Getting the current reaction table if not provided at input
	if (!defined($tbl)) {
		$tbl = $self->reaction_table();
	}
	for (my $i=0; $i < $tbl->size(); $i++) {
		my $row = $tbl->get_row($i);
		my $orgRow = $originalReactions->get_row_by_key($row->{LOAD}->[0],"LOAD");
		if (!defined($orgRow)) {
			if (defined($row->{"ASSOCIATED PEG"}->[0])) {
				$self->figmodel()->database()->create_object("mdlhist",{TRANSACTION=>$mdlHistTransObj->_id(),REACTION=>$row->{LOAD}->[0],directionality=>$row->{DIRECTIONALITY}->[0],compartment=>$row->{COMPARTMENT}->[0],pegs=>join("|",@{$row->{"ASSOCIATED PEG"}}),action=>"ADDED"});
			} else {
				$self->figmodel()->database()->create_object("mdlhist",{TRANSACTION=>$mdlHistTransObj->_id(),REACTION=>$row->{LOAD}->[0],directionality=>$row->{DIRECTIONALITY}->[0],compartment=>$row->{COMPARTMENT}->[0],pegs=>"NONE",action=>"ADDED"});
			}
		} else {
			my $geneChanges;
			my $directionChange = $row->{"DIRECTIONALITY"}->[0];
			if ($orgRow->{"DIRECTIONALITY"}->[0] ne $row->{"DIRECTIONALITY"}->[0]) {
				$directionChange = $orgRow->{"DIRECTIONALITY"}->[0]."|".$row->{"DIRECTIONALITY"}->[0];
			}
			for (my $j=0; $j < @{$row->{"ASSOCIATED PEG"}}; $j++) {
				my $match = 0;
				if (defined($orgRow->{"ASSOCIATED PEG"})) {
					for (my $k=0; $k < @{$orgRow->{"ASSOCIATED PEG"}}; $k++) {
						if ($row->{"ASSOCIATED PEG"}->[$j] eq $orgRow->{"ASSOCIATED PEG"}->[$k]) {
							$match = 1;	
						}
					}
				}
				if ($match == 0) {
					push(@{$geneChanges},"Added ".$row->{"ASSOCIATED PEG"}->[$j]);
				}
			}
			if (defined($orgRow->{"ASSOCIATED PEG"})) {
				for (my $k=0; $k < @{$orgRow->{"ASSOCIATED PEG"}}; $k++) {
					my $match = 0;
					if (defined($row->{"ASSOCIATED PEG"})) {
						for (my $j=0; $j < @{$row->{"ASSOCIATED PEG"}}; $j++) {
							if ($row->{"ASSOCIATED PEG"}->[$j] eq $orgRow->{"ASSOCIATED PEG"}->[$k]) {
								$match = 1;
							}
						}
					}
					if ($match == 0) {
						push(@{$geneChanges},"Removed ".$orgRow->{"ASSOCIATED PEG"}->[$k]);
					}
				}
			}
			if ((defined($directionChange) && length($directionChange) > 0) || defined($geneChanges) && @{$geneChanges} > 0) {
				if (!defined($geneChanges)) {
					$geneChanges = "NONE";
				} else {
					$geneChanges = join("|",@{$geneChanges});
				}
				$self->figmodel()->database()->create_object("mdlhist",{TRANSACTION=>$mdlHistTransObj->_id(),REACTION=>$row->{LOAD}->[0],directionality=>$directionChange,compartment=>$row->{COMPARTMENT}->[0],pegs=>$geneChanges,action=>"CHANGE"});
			}
		}
	}
	#Looking for removed reactions
	for (my $i=0; $i < $originalReactions->size(); $i++) {
		my $row = $originalReactions->get_row($i);
		my $orgRow = $tbl->get_row_by_key($row->{LOAD}->[0],"LOAD");
		if (!defined($orgRow)) {
			if (defined($row->{"ASSOCIATED PEG"}->[0])) {
				$self->figmodel()->database()->create_object("mdlhist",{TRANSACTION=>$mdlHistTransObj->_id(),REACTION=>$row->{LOAD}->[0],directionality=>$row->{DIRECTIONALITY}->[0],compartment=>$row->{COMPARTMENT}->[0],pegs=>join("|",@{$row->{"ASSOCIATED PEG"}}),action=>"REMOVED"});
			} else {
				$self->figmodel()->database()->create_object("mdlhist",{TRANSACTION=>$mdlHistTransObj->_id(),REACTION=>$row->{LOAD}->[0],directionality=>$row->{DIRECTIONALITY}->[0],compartment=>$row->{COMPARTMENT}->[0],pegs=>"NONE",action=>"REMOVED"});
			}
		}
	}
	#Deleting the file with the old reactions
	if (defined($filename) && -e $self->directory()."OriginalModel-".$self->id()."-".$filename.".txt") {
		unlink($self->directory()."OriginalModel-".$self->id()."-".$filename.".txt");
	}
}

=head3 GapGenModel
Definition:
	FIGMODELmodel->GapGenModel();
Description:
	Runs the gap generation algorithm to correct a single false positive prediction. Results are loaded into a table.
=cut

sub GapGenModel {
	my ($self,$Media,$KOList,$NoKOList,$Experiment,$SolutionLimit) = @_;
	
	#Enforcing nonoptional arguments
	if (!defined($Media)) {
		return undef;
	}
	if (!defined($KOList)) {
		$KOList->[0] = "none";
	}
	if (!defined($NoKOList)) {
		$NoKOList->[0] = "none";
	}
	if (!defined($Experiment)) {
		$Experiment= "ReactionKO";
	}
	if (!defined($SolutionLimit)) {
		$SolutionLimit = "10";
	}
	
	#Translating the KO lists into arrays
	if (ref($KOList) ne "ARRAY") {
		my $temp = $KOList;
		$KOList = ();
		push(@{$KOList},split(/[,;]/,$temp));	
	}
	my $noKOHash;
	if (defined($NoKOList) && ref($NoKOList) ne "ARRAY") {
		my $temp = $NoKOList;
		$NoKOList = ();
		push(@{$NoKOList},split(/[,;]/,$temp));
		foreach my $rxn (@{$NoKOList}) {
			$noKOHash->{$rxn} = 1;
		}
	}
	
	#Checking if solutions exist for the input parameters
	$self->aquireModelLock();
	my $tbl = $self->load_model_table("GapGenSolutions");
	my $solutionRow = $tbl->get_table_by_key($Experiment,"Experiment")->get_table_by_key($Media,"Media")->get_row_by_key(join(",",@{$KOList}),"KOlist");
	my $solutions;
	if (defined($solutionRow)) {
		#Checking if any solutions conform to the no KO list
		foreach my $solution (@{$solutionRow->{Solutions}}) {
			my @reactions = split(/,/,$solution);
			my $include = 1;
			foreach my $rxn (@reactions) {
				if ($rxn =~ m/(rxn\d\d\d\d\d)/) {
					if (defined($noKOHash->{$1})) {
						$include = 0;
					}
				}
			}
			if ($include == 1) {
				push(@{$solutions},$solution);
			}
		}
	} else {
		$solutionRow = {Media => [$Media],Experiment => [$Experiment],KOlist => [join(",",@{$KOList})]};
		$tbl->add_row($solutionRow);
		$self->figmodel()->database()->save_table($tbl);
	}
	$self->releaseModelLock();
	
	#Returning solution list of solutions were found
	if (defined($solutions) && @{$solutions} > 0) {
		return $solutions;
	}
	
	#Getting unique filename
	my $Filename = $self->figmodel()->filename();

	#Running the gap generation
	system($self->figmodel()->GenerateMFAToolkitCommandLineCall($Filename,$self->id().$self->selected_version(),$Media,["GapGeneration"],{"Recursive MILP solution limit" => $SolutionLimit ,"Reactions that should always be active" => join(";",@{$NoKOList}),"Reactions to knockout" => join(";",@{$KOList}),"Reactions that are always blocked" => "none"},"Gapgeneration-".$self->id().$self->selected_version()."-".$Filename.".log",undef,undef));
	my $ProblemReport = $self->figmodel()->LoadProblemReport($Filename);
	if (!defined($ProblemReport)) {
		$self->figmodel()->error_message("FIGMODEL:GapGenerationAlgorithm;No problem report;".$Filename.";".$self->id().$self->selected_version().";".$Media.";".$KOList.";".$NoKOList);
		return undef;
	}
	
	#Clearing the output folder and log file
	$self->figmodel()->clearing_output($Filename,"Gapgeneration-".$self->id().$self->selected_version()."-".$Filename.".log");
	
	#Saving the solution
	$self->aquireModelLock();
	$tbl = $self->load_model_table("GapGenSolutions");
	$solutionRow = $tbl->get_table_by_key($Experiment,"Experiment")->get_table_by_key($Media,"Media")->get_row_by_key(join(",",@{$KOList}),"KOlist");
	for (my $j=0; $j < $ProblemReport->size(); $j++) {
		if ($ProblemReport->get_row($j)->{"Notes"}->[0] =~ m/^Recursive\sMILP\s([^)]+)/) {
			my @SolutionList = split(/\|/,$1);
			for (my $k=0; $k < @SolutionList; $k++) {
				if ($SolutionList[$k] =~ m/(\d+):(.+)/) {
					push(@{$solutionRow->{Solutions}},$2);
					push(@{$solutions},$2);
				}
			}
		}
	}
	$self->figmodel()->database()->save_table($tbl);
	$self->releaseModelLock();
	
	return $solutions;
}

=head3 datagapfill
Definition:
	success()/fail() = FIGMODELmodel->datagapfill();
Description:
	Run gapfilling on the input run specifications
=cut
sub datagapfill {
	my ($self,$GapFillingRunSpecs,$TansferFileSuffix) = @_;
	my $UniqueFilename = $self->figmodel()->filename();
	if (defined($GapFillingRunSpecs) && @{$GapFillingRunSpecs} > 0) {
		system($self->figmodel()->GenerateMFAToolkitCommandLineCall($UniqueFilename,$self->id().$self->selected_version(),"NoBounds",["GapFilling"],{"Reactions to knockout" => $self->config("permanently knocked out reactions")->[0],"Gap filling runs" => join(";",@{$GapFillingRunSpecs})},"GapFilling-".$self->id().$self->selected_version()."-".$UniqueFilename.".log",undef,undef));
		#Checking that the solution exists
		if (!-e $self->config("MFAToolkit output directory")->[0].$UniqueFilename."/GapFillingSolutionTable.txt") {
			$self->figmodel()->error_message("FIGMODEL:GapFillingAlgorithm: Could not find MFA output file!");
			$self->figmodel()->database()->print_array_to_file($self->directory().$self->id().$self->selected_version()."-GFS.txt",["Experiment;Solution index;Solution cost;Solution reactions"]);
			return undef;
		}
		my $GapFillResultTable = $self->figmodel()->database()->load_table($self->config("MFAToolkit output directory")->[0].$UniqueFilename."/GapFillingSolutionTable.txt",";","",0,undef);
		if (defined($TansferFileSuffix)) {
			system("cp ".$self->config("MFAToolkit output directory")->[0].$UniqueFilename."/GapFillingSolutionTable.txt ".$self->directory().$self->id().$self->selected_version()."-".$TansferFileSuffix.".txt");
		}
		#If the system is not configured to preserve all logfiles, then the mfatoolkit output folder is deleted
		print $self->config("MFAToolkit output directory")->[0].$UniqueFilename."\n";
		$self->figmodel()->clearing_output($UniqueFilename,"GapFilling-".$self->id().$self->selected_version()."-".$UniqueFilename.".log");
		return $GapFillResultTable;
	}
	if (defined($TansferFileSuffix)) {
		$self->figmodel()->database()->print_array_to_file($self->directory().$self->id().$self->selected_version()."-".$TansferFileSuffix.".txt",["Experiment;Solution index;Solution cost;Solution reactions"]);
	}
	return undef;
}

=head3 TestSolutions
Definition:
	$model->TestSolutions($ModelID,$NumProcessors,$ProcessorIndex,$GapFill);
Description:
Example:
=cut

sub TestSolutions {
	my ($self,$OriginalErrorFilename,$GapFillResultTable) = @_;
	#Getting the filename
	my $UniqueFilename = $self->figmodel()->filename();
	#Reading in the original error matrix which has the headings for the original model simulation
	my $OriginalErrorData;
	if (!defined($OriginalErrorFilename) || !-e $self->directory().$OriginalErrorFilename) {
		my ($FalsePostives,$FalseNegatives,$CorrectNegatives,$CorrectPositives,$Errorvector,$HeadingVector) = $self->RunAllStudiesWithDataFast("All");
		$OriginalErrorData = [$HeadingVector,$Errorvector];
	} else {
		$OriginalErrorData = $self->figmodel()->database()->load_single_column_file($self->directory().$OriginalErrorFilename,"");
	}
	my $HeadingHash;
	my @HeadingArray = split(/;/,$OriginalErrorData->[0]);
	my @OrigErrorArray = split(/;/,$OriginalErrorData->[1]);
	for (my $i=0; $i < @HeadingArray; $i++) {
		my @SubArray = split(/:/,$HeadingArray[$i]);
		$HeadingHash->{$SubArray[0].":".$SubArray[1].":".$SubArray[2]} = $i;
	}
	#Scanning through the gap filling solutions
	my $TempVersion = "V".$UniqueFilename;
	my $ErrorMatrixLines;
	for (my $i=0; $i < $GapFillResultTable->size(); $i++) {
		print "Starting problem solving ".$i."\n";
		my $ErrorLine = $GapFillResultTable->get_row($i)->{"Experiment"}->[0].";".$GapFillResultTable->get_row($i)->{"Solution index"}->[0].";".$GapFillResultTable->get_row($i)->{"Solution cost"}->[0].";".$GapFillResultTable->get_row($i)->{"Solution reactions"}->[0];
		#Integrating solution into test model
		my $ReactionArray;
		my $DirectionArray;
		my @ReactionList = split(/,/,$GapFillResultTable->get_row($i)->{"Solution reactions"}->[0]);
		my %SolutionHash;
		for (my $k=0; $k < @ReactionList; $k++) {
			if ($ReactionList[$k] =~ m/(.+)(rxn\d\d\d\d\d)/) {
				my $Reaction = $2;
				my $Sign = $1;
				if (defined($SolutionHash{$Reaction})) {
					$SolutionHash{$Reaction} = "<=>";
				} elsif ($Sign eq "-") {
					$SolutionHash{$Reaction} = "<=";
				} elsif ($Sign eq "+") {
					$SolutionHash{$Reaction} = "=>";
				} else {
					$SolutionHash{$Reaction} = $Sign;
				}
			}
		}
		@ReactionList = keys(%SolutionHash);
		for (my $k=0; $k < @ReactionList; $k++) {
			push(@{$ReactionArray},$ReactionList[$k]);
			push(@{$DirectionArray},$SolutionHash{$ReactionList[$k]});
		}
		print "Integrating solution!\n";
		$self->figmodel()->IntegrateGrowMatchSolution($self->id().$self->selected_version(),$self->directory().$self->id().$TempVersion.".txt",$ReactionArray,$DirectionArray,"Gapfilling ".$GapFillResultTable->get_row($i)->{"Experiment"}->[0],1,1);
		$self->PrintModelLPFile();
		#Running the model against all available experimental data
		print "Running test model!\n";
		my ($FalsePostives,$FalseNegatives,$CorrectNegatives,$CorrectPositives,$Errorvector,$HeadingVector) = $self->RunAllStudiesWithDataFast("All");

		@HeadingArray = split(/;/,$HeadingVector);
		my @ErrorArray = @OrigErrorArray;
		my @TempArray = split(/;/,$Errorvector);
		for (my $j=0; $j < @HeadingArray; $j++) {
			my @SubArray = split(/:/,$HeadingArray[$j]);
			$ErrorArray[$HeadingHash->{$SubArray[0].":".$SubArray[1].":".$SubArray[2]}] = $TempArray[$j];
		}
		$ErrorLine .= ";".$FalsePostives."/".$FalseNegatives.";".join(";",@ErrorArray);
		push(@{$ErrorMatrixLines},$ErrorLine);
		print "Finishing problem solving ".$i."\n";
	}
	#Clearing out the test model
	if (-e $self->directory().$self->id().$TempVersion.".txt") {
		unlink($self->directory().$self->id().$TempVersion.".txt");
		unlink($self->directory()."SimulationOutput".$self->id().$TempVersion.".txt");
	}
	return $ErrorMatrixLines;
}

=head3 CreateMetabolicModel
Definition:
	FIGMODELmodel->CreateMetabolicModel();
Description:
=cut
sub CreateMetabolicModel {
	my ($self,$RunGapFilling) = @_;
	#Getting genome data and feature table
	my $genomeObj = $self->genomeObj();
	if (!defined($genomeObj)) {
		$self->set_status(0,"Could not create genome object!");
		return {error => $self->error_message("CreateMetabolicModel:could not create genome object!")};
	}
	my $ftrTbl = $genomeObj->feature_table();
	if ($genomeObj->source() eq "UNKNOWN") {
		$self->set_status(0,"Could not find genome in RAST, SEED, PSEED, or MGRAST!");
		return {error => $self->error_message("CreateMetabolicModel:could not find genome in RAST, SEED, PSEED, or MGRAST!")};
	}
	if (!defined($ftrTbl)) {
		$self->set_status(0,"Could not obtain feature table for genome!");
		return {error => $self->error_message("CreateMetabolicModel:could not obtain feature table!")};
	}
	#Checking that the number of genes exceeds the minimum size
	if ($ftrTbl->size() < $self->config("minimum genome size for modeling")->[0]) {
		$self->set_status(-1,"Genome too small for modeling!");
	}
	#Creating model directory
	if (!-d $self->figmodel()->config("organism directory")->[0].$self->owner()."/") {
		system("mkdir ".$self->figmodel()->config("organism directory")->[0].$self->owner()."/");
	}
	if (!-d $self->figmodel()->config("organism directory")->[0].$self->owner()."/".$self->genome()."/") {
		system("mkdir ".$self->figmodel()->config("organism directory")->[0].$self->owner()."/".$self->genome()."/");
	}
	#Setting up needed variables
	my $OriginalModelTable = undef;
	if ($self->status() == 0) {
		return {error => $self->error_message("CreateMetabolicModel: model is already being built. Canceling current build.")};
	}elsif ($self->status() == 1) {
		$OriginalModelTable = $self->reaction_table();
		$self->set_status(0,"Rebuilding preliminary reconstruction");
	} else {
		$self->set_status(0,"Preliminary reconstruction");
	}
	#Populating datastructures for the GPR generation function from the feature table
	my ($escores,$functional_roles,$mapped_DNA,$locations);
	for (my $i=0; $i < $ftrTbl->size(); $i++) {
		my $row = $ftrTbl->get_row($i);
		my $geneID = $row->{ID}->[0];
		if ($genomeObj->source() eq "MGRAST" && $geneID =~ m/(\d+\.\d+\.peg\.\d+)/) {
			$geneID = $1;
		} elsif ($geneID =~ m/(peg\.\d+)/) {
			$geneID = $1;
		}
		if (defined($row->{ROLES}->[0])) {
			for (my $j=0; $j < @{$row->{ROLES}}; $j++) {
				push(@{$functional_roles},$row->{ROLES}->[$j]);
				push(@{$mapped_DNA},$geneID);
				if (defined($row->{"MIN LOCATION"}->[0]) && defined($row->{"MAX LOCATION"}->[0])) {
					my $average = ($row->{"MIN LOCATION"}->[0]+$row->{"MAX LOCATION"}->[0])/2;
					push(@{$locations},$average);
				} elsif (defined($row->{"MIN LOCATION"}->[0])) {
					push(@{$locations},$row->{"MIN LOCATION"}->[0]);
				} elsif (defined($row->{"MAX LOCATION"}->[0])) {
					push(@{$locations},$row->{"MAX LOCATION"}->[0]);
				} else {
					push(@{$locations},-1);
				}
			}
		}
		if (defined($row->{EVALUE})) {
			$escores->{$geneID} = $row->{EVALUE};
		}
	}
	my $ReactionHash = $self->generate_model_gpr($functional_roles,$mapped_DNA,$locations);
	if (!defined($ReactionHash)) {
		return {error => $self->error_message("CreateMetabolicModel: could not generate reaction GPR!")};
	}
	#Creating the model reaction table
	my $NewModelTable = ModelSEED::FIGMODEL::FIGMODELTable->new(["LOAD","DIRECTIONALITY","COMPARTMENT","ASSOCIATED PEG","SUBSYSTEM","CONFIDENCE","REFERENCE","NOTES"],$self->directory().$self->id().".txt",["LOAD"],";","|","REACTIONS\n");
	my @ReactionList = keys(%{$ReactionHash});
	foreach my $ReactionID (@ReactionList) {
		#Getting the thermodynamic reversibility from the database
		my $Directionality = $self->figmodel()->reversibility_of_reaction($ReactionID);
		my $Subsystem = "NONE";
		my $confidence = [3];
		if (defined($escores)) {
			$confidence = [];
			for (my $i=0; $i < @{$ReactionHash->{$ReactionID}}; $i++) {
				if (defined($escores->{$ReactionHash->{$ReactionID}->[$i]})) {
					push(@{$confidence}, join(";",@{$escores->{$ReactionHash->{$ReactionID}->[$i]}}));
				}
			}
		}
		$NewModelTable->add_row({"LOAD" => [$ReactionID],"DIRECTIONALITY" => [$Directionality],"COMPARTMENT" => ["c"],"ASSOCIATED PEG" => [join("|",@{$ReactionHash->{$ReactionID}})],"SUBSYSTEM" => [$Subsystem],"CONFIDENCE" => $confidence,"REFERENCE" => [$genomeObj->source()],"NOTES" => ["NONE"]});
	}
	#Adding the spontaneous and universal reactions
	foreach my $ReactionID (@{$self->config("spontaneous reactions")}) {
		#Getting the thermodynamic reversibility from the database
		my $Directionality = $self->figmodel()->reversibility_of_reaction($ReactionID);
		#Checking if the reaction is already in the model
		if (!defined($NewModelTable->get_row_by_key($ReactionID,"LOAD"))) {
			$NewModelTable->add_row({"LOAD" => [$ReactionID],"DIRECTIONALITY" => [$Directionality],"COMPARTMENT" => ["c"],"ASSOCIATED PEG" => ["SPONTANEOUS"],"SUBSYSTEM" => ["NONE"],"CONFIDENCE" => [4],"REFERENCE" => ["SPONTANEOUS"],"NOTES" => ["NONE"]});
		}
	}
	foreach my $ReactionID (@{$self->config("universal reactions")}) {
		#Getting the thermodynamic reversibility from the database
		my $Directionality = $self->figmodel()->reversibility_of_reaction($ReactionID);
		#Checking if the reaction is already in the model
		if (!defined($NewModelTable->get_row_by_key($ReactionID,"LOAD"))) {
			$NewModelTable->add_row({"LOAD" => [$ReactionID],"DIRECTIONALITY" => [$Directionality],"COMPARTMENT" => ["c"],"ASSOCIATED PEG" => ["UNIVERSAL"],"SUBSYSTEM" => ["NONE"],"CONFIDENCE" => [4],"REFERENCE" => ["UNIVERSAL"],"NOTES" => ["NONE"]});
		}
	}
	#Completing any incomplete reactions sets
	if (defined($self->figmodel()->config("reaction sets"))) {
		foreach my $rxn (keys(%{$self->figmodel()->config("reaction sets")})) {
			if (defined($NewModelTable->get_row_by_key($rxn,"LOAD"))) {
				foreach my $Reaction (@{$self->figmodel()->config("reaction sets")->{$rxn}}) {
					if (!defined($NewModelTable->get_row_by_key($Reaction,"LOAD"))) {
						#Getting the thermodynamic reversibility from the database
						my $Directionality = $self->figmodel()->reversibility_of_reaction($Reaction);
						$NewModelTable->add_row({"LOAD" => [$Reaction],"DIRECTIONALITY" => [$Directionality],"COMPARTMENT" => ["c"],"ASSOCIATED PEG" => ["REACTION SET GAP FILLING"],"SUBSYSTEM" => ["NONE"],"CONFIDENCE" => [5],"REFERENCE" => ["Added due to presence of ".$rxn],"NOTES" => ["NONE"]});
					}
				}
			}
		}
	}
	#Creating biomass reaction for model
	my $biomassID;
	if ($genomeObj->source() eq "MGRAST") {
		$biomassID = "bio00001";
	} else {
		$biomassID = $self->BuildSpecificBiomassReaction();
		if ($biomassID !~ m/bio\d\d\d\d\d/) {
			$self->set_status(-2,"Preliminary reconstruction failed: could not generate biomass reaction");
			return {error => $self->error_message("CreateSingleGenomeReactionList: Could not generate biomass reaction!")};
		}
	}
	if ($biomassID !~ m/bio\d\d\d\d\d/) {
		return {error => $self->error_message("CreateMetabolicModel: Could not create biomass reaction!")};
	}
	#Getting the biomass reaction PPO object
	my $bioRxn = $self->figmodel()->database()->get_object("bof",{id=>$biomassID});
	if (!defined($bioRxn)) {
		return {error => $self->error_message("CreateMetabolicModel: Could not find biomass reaction ".$biomassID."!")};
	}
	#Getting the list of essential reactions for biomass reaction
	my $ReactionList;
	my $essentialReactions = $bioRxn->essentialRxn();
	if (defined($essentialReactions) && $essentialReactions =~ m/rxn\d\d\d\d\d/) {
		push(@{$ReactionList},split(/\|/,$essentialReactions));
		if ($essentialReactions !~ m/$biomassID/) {
			push(@{$ReactionList},$biomassID);
		}
	} else {
		push(@{$ReactionList},$biomassID);
	}
	#Adding biomass reactions to the model table
	foreach my $BOFReaction (@{$ReactionList}) {
		#Getting the thermodynamic reversibility from the database
		my $Directionality = $self->figmodel()->reversibility_of_reaction($BOFReaction);
		#Checking if the reaction is already in the model
		if (!defined($NewModelTable->get_row_by_key($BOFReaction,"LOAD"))) {
			if ($BOFReaction =~ m/bio/) {
				$NewModelTable->add_row({"LOAD" => [$BOFReaction],"DIRECTIONALITY" => [$Directionality],"COMPARTMENT" => ["c"],"ASSOCIATED PEG" => ["BOF"],"SUBSYSTEM" => ["NONE"],"CONFIDENCE" => [1],"REFERENCE" => ["Biomass objective function"],"NOTES" => ["NONE"]});
			} else {
				$NewModelTable->add_row({"LOAD" => [$BOFReaction],"DIRECTIONALITY" => [$Directionality],"COMPARTMENT" => ["c"],"ASSOCIATED PEG" => ["INITIAL GAP FILLING"],"SUBSYSTEM" => ["NONE"],"CONFIDENCE" => [5],"REFERENCE" => ["Initial gap filling"],"NOTES" => ["NONE"]});
			}
		}
	}
	#If an original model exists, we copy the gap filling solution from that model
	if (defined($OriginalModelTable)) {
		for (my $i=0; $i < $OriginalModelTable->size(); $i++) {
			if ($OriginalModelTable->get_row($i)->{"ASSOCIATED PEG"}->[0] =~ m/GAP/ && $OriginalModelTable->get_row($i)->{"ASSOCIATED PEG"}->[0] ne "INITIAL GAP FILLING") {
				my $Row = $NewModelTable->get_row_by_key($OriginalModelTable->get_row($i)->{"LOAD"}->[0],"LOAD");
				if (!defined($Row)) {
					$NewModelTable->add_row($OriginalModelTable->get_row($i));
				}
			}
		}
	}
	#Now we compare the model to the previous model to determine if any differences exist that aren't gap filling reactions
	if (defined($OriginalModelTable)) {
		my $PerfectMatch = 1;
		my $ReactionCount = 0;
		for (my $i=0; $i < $OriginalModelTable->size(); $i++) {
			#We only check that nongapfilling reactions exist in the new model
			if ($OriginalModelTable->get_row($i)->{"ASSOCIATED PEG"}->[0] !~ m/GAP/ || $OriginalModelTable->get_row($i)->{"ASSOCIATED PEG"}->[0] eq "INITIAL GAP FILLING") {
				$ReactionCount++;
				my $Row = $NewModelTable->get_row_by_key($OriginalModelTable->get_row($i)->{"LOAD"}->[0],"LOAD");
				if (defined($Row)) {
					#We check that the reaction directionality is identical
					if ($Row->{"DIRECTIONALITY"}->[0] ne $OriginalModelTable->get_row($i)->{"DIRECTIONALITY"}->[0]) {
						if (defined($OriginalModelTable->get_row($i)->{"NOTES"}->[0]) && $OriginalModelTable->get_row($i)->{"NOTES"}->[0] =~ m/Directionality\sswitched\sfrom\s([^\s])/) {
							if ($1 ne $Row->{"DIRECTIONALITY"}->[0]) {
								print "Directionality mismatch for reaction ".$OriginalModelTable->get_row($i)->{"LOAD"}->[0].": ".$1." vs ".$Row->{"DIRECTIONALITY"}->[0]."\n";
								$PerfectMatch = 0;
								last;
							}
						} else {
							print "Directionality mismatch for reaction ".$OriginalModelTable->get_row($i)->{"LOAD"}->[0].": ".$OriginalModelTable->get_row($i)->{"DIRECTIONALITY"}->[0]." vs ".$Row->{"DIRECTIONALITY"}->[0]."\n";
							$PerfectMatch = 0;
							last;
						}
					}
					#We check that the genes assigned to the reaction are identical
					if ($PerfectMatch == 1 && @{$OriginalModelTable->get_row($i)->{"ASSOCIATED PEG"}} != @{$Row->{"ASSOCIATED PEG"}}) {
						print "Gene associatation mismatch for reaction ".$OriginalModelTable->get_row($i)->{"LOAD"}->[0].": ".@{$OriginalModelTable->get_row($i)->{"ASSOCIATED PEG"}}." vs ".@{$Row->{"ASSOCIATED PEG"}}."\n";
						$PerfectMatch = 0;
						last;
					}
					if ($PerfectMatch == 1) {
						my @GeneSetOne = sort(@{$OriginalModelTable->get_row($i)->{"ASSOCIATED PEG"}});
						my @GeneSetTwo = sort(@{$Row->{"ASSOCIATED PEG"}});
						for (my $j=0; $j < @GeneSetOne; $j++) {
							if ($GeneSetOne[$j] ne $GeneSetTwo[$j]) {
								print "Gene mismatch for reaction ".$OriginalModelTable->get_row($i)->{"LOAD"}->[0].": ".$GeneSetOne[$j]." vs ".$GeneSetTwo[$j]."\n";
								$PerfectMatch = 0;
								$i = $OriginalModelTable->size();
								last;
							}
						}
					}
				} else {
					print "Original model contains an extra reaction:".$OriginalModelTable->get_row($i)->{"LOAD"}->[0]."\n";
					$PerfectMatch = 0;
					last;
				}
			}
		}
		if ($PerfectMatch == 1 && $ReactionCount == $NewModelTable->size()) {
			#Bailing out of function as the model has not changed
			$self->set_status(1,"Rebuild canceled because model has not changed");
			return undef;
		}
	}
	#Saving the new model to file
	$self->set_status(1,"Preliminary reconstruction complete");
	$self->figmodel()->database()->save_table($NewModelTable);
	$self->reaction_table(1);
	#Updating the model stats table
	#if (defined($OriginalModelTable)) {
		#my $filename = $self->figmodel()->filename();
		#$OriginalModelTable->save($self->directory()."OriginalModel-".$self->id()."-".$filename.".txt");
		#system($self->figmodel()->config("Model driver executable")->[0]." \"calculatemodelchanges?".$self->id()."?".$filename."?Rebuild\"");
	#}
	#Canceling gapfilling if number of reactions is too small
	if ($NewModelTable->size() < 100) {
		$RunGapFilling = 0;
		$self->set_status(1,"Reconstruction complete. Genome too small for gapfilling.");
	}
	#Adding model to gapfilling queue
	if (defined($RunGapFilling) && $RunGapFilling == 1) {
		$self->set_status(1,"Autocompletion queued");
		$self->figmodel()->add_job_to_queue({command => "gapfillmodel?".$self->id(),user => $self->owner(),queue => "cplex"});
	}
	$self->processModel();
	return undef;
}

=head3 generate_model_gpr
Definition:
	{string:reaction id => [string]:complexes} = FIGMODELmodel->generate_model_gpr([string]:functional roles,[string]:mapped DNA,[double]:locations);
=cut

sub generate_model_gpr {
	my ($self,$functional_roles,$mapped_DNA,$locations) = @_;
	#Putting the gene locations into a hash for the gene ids
	my $geneLocations;
	if (defined($locations)) {
		for (my $i=0; $i < @{$mapped_DNA}; $i++) {
			$geneLocations->{$mapped_DNA->[$i]} = $locations->[$i];
		}
	}
	#Converting the functional roles to IDs
	my $roleHash;
	for (my $i=0; $i < @{$functional_roles}; $i++) {
		my @roles = $self->figmodel()->roles_of_function($functional_roles->[$i]);
		for (my $j=0; $j < @roles; $j++) {
			my $searchname = $self->figmodel()->convert_to_search_role($roles[$j]);
			my $roleObj = $self->figmodel()->database()->get_object("role",{searchname => $searchname});
			if (defined($roleObj)) {
				$roleHash->{$roleObj->id()}->{$mapped_DNA->[$i]} = 1;
			}
		}
	}
	#Getting the entire list of complexes mapped to reaction and saving mapping into a hash
	my $complexHash;
	my $rxncpxs = $self->figmodel()->database()->get_objects("rxncpx");
	for (my $i=0; $i < @{$rxncpxs}; $i++) {
		if ($rxncpxs->[$i]->master() == 1) {
			push(@{$complexHash->{$rxncpxs->[$i]->COMPLEX()}},$rxncpxs->[$i]->REACTION());
		}
	}
	#Getting the functional roles associated with each complex
	my $modelComplexes;
	my $cpxroles = $self->figmodel()->database()->get_objects("cpxrole");
	for (my $i=0; $i < @{$cpxroles}; $i++) {
		if (defined($complexHash->{$cpxroles->[$i]->COMPLEX()})) {
			if ($cpxroles->[$i]->type() ne "N") {
				if (defined($roleHash->{$cpxroles->[$i]->ROLE()})) {
					push(@{$modelComplexes->{$cpxroles->[$i]->COMPLEX()}->{$cpxroles->[$i]->type()}->{$cpxroles->[$i]->ROLE()}},keys(%{$roleHash->{$cpxroles->[$i]->ROLE()}}));
				}
			}
		}
	}
	#Forming the GPR for each complex
	my $complexGPR;
	my @complexes = keys(%{$modelComplexes});
	for (my $i=0; $i < @complexes; $i++) {
		if (defined($modelComplexes->{$complexes[$i]}->{"G"})) {
			my @roles = keys(%{$modelComplexes->{$complexes[$i]}->{"G"}});
			#Counting the number of possible combinations to determine if we should bother with complexes
			my $totalComplexes = 1;
			for (my $j=0; $j < @roles; $j++) {
				$totalComplexes = $totalComplexes*@{$modelComplexes->{$complexes[$i]}->{"G"}->{$roles[$j]}};
			}
			#If the number of possible complexes is too large, we just add all genes as "or" associations
			if ($totalComplexes > 20 || !defined($locations)) {
				for (my $j=0; $j < @roles; $j++) {
					push(@{$complexGPR->{$complexes[$i]}},@{$modelComplexes->{$complexes[$i]}->{"G"}->{$roles[$j]}});
				}
			} else {
				#Identifying colocalized pairs of roles and combining their GPR
				for (my $j=0; $j < @roles; $j++) {
					for (my $k=$j+1; $k < @roles; $k++) {
						my $colocalized = 0;
						my $newGPR;
						my $foundHash;
						for (my $m=0; $m < @{$modelComplexes->{$complexes[$i]}->{"G"}->{$roles[$j]}}; $m++) {
							my @genes = split(/\+/,$modelComplexes->{$complexes[$i]}->{"G"}->{$roles[$j]}->[$m]);
							my $found = 0;
							for (my $n=0; $n < @genes; $n++) {
								for (my $o=0; $o < @{$modelComplexes->{$complexes[$i]}->{"G"}->{$roles[$k]}}; $o++) {
									if (abs($geneLocations->{$genes[$n]}-$geneLocations->{$modelComplexes->{$complexes[$i]}->{"G"}->{$roles[$k]}->[$o]}) < 5000) {
										push(@{$newGPR},$modelComplexes->{$complexes[$i]}->{"G"}->{$roles[$j]}->[$m]."+".$modelComplexes->{$complexes[$i]}->{"G"}->{$roles[$k]}->[$o]);
										$foundHash->{$modelComplexes->{$complexes[$i]}->{"G"}->{$roles[$k]}->[$o]} = 1;
										$found = 1;
										last;
									}
								}
								if ($found == 1) {
									last;	
								}
							}
							if ($found == 1) {
								$colocalized++;
							} else {
								push(@{$newGPR},$modelComplexes->{$complexes[$i]}->{"G"}->{$roles[$j]}->[$m]);
							}
						}
						#If over half the genes associated with both roles are colocalized, we combine the roles into a single set of GPR
						if ($colocalized/@{$modelComplexes->{$complexes[$i]}->{"G"}->{$roles[$j]}} > 0.5 && $colocalized/@{$modelComplexes->{$complexes[$i]}->{"G"}->{$roles[$k]}} > 0.5) {
							#Adding any noncolocalized genes found in the second role
							for (my $o=0; $o < @{$modelComplexes->{$complexes[$i]}->{"G"}->{$roles[$k]}}; $o++) {
								if (!defined($foundHash->{$modelComplexes->{$complexes[$i]}->{"G"}->{$roles[$k]}->[$o]})) {
									push(@{$newGPR},$modelComplexes->{$complexes[$i]}->{"G"}->{$roles[$k]}->[$o]);
								}
							}
							#Replacing the old GPR for the first role with the new combined GPR
							$modelComplexes->{$complexes[$i]}->{"G"}->{$roles[$j]} = $newGPR;
							#Deleting the second role
							splice(@roles,$k,1);
							$k--;
						}
					}
				}
				#Combinatorially creating all remaining complexes
				push(@{$complexGPR->{$complexes[$i]}},@{$modelComplexes->{$complexes[$i]}->{"G"}->{$roles[0]}});
				for (my $j=1; $j < @roles; $j++) {
					my $newMappings;
					for (my $m=0; $m < @{$complexGPR->{$complexes[$i]}}; $m++) {
						for (my $k=0; $k < @{$modelComplexes->{$complexes[$i]}->{"G"}->{$roles[$j]}}; $k++) {
							push(@{$newMappings},$complexGPR->{$complexes[$i]}->[$m]."+".$modelComplexes->{$complexes[$i]}->{"G"}->{$roles[$j]}->[$k]);
						}
					}
					$complexGPR->{$complexes[$i]} = $newMappings;
				}
			}
			#Adding global generic complex elements
			if (defined($modelComplexes->{$complexes[$i]}->{"L"})) {
				my $totalComplexes = @{$complexGPR->{$complexes[$i]}};
				@roles = keys(%{$modelComplexes->{$complexes[$i]}->{"L"}});
				for (my $j=0; $j < @roles; $j++) {
					$totalComplexes = $totalComplexes*@{$modelComplexes->{$complexes[$i]}->{"L"}->{$roles[$j]}};
				}
				if ($totalComplexes < 20) {
					for (my $j=0; $j < @roles; $j++) {
						my $newGeneAssociations;
						for (my $k=0; $k < @{$modelComplexes->{$complexes[$i]}->{"L"}->{$roles[$j]}}; $k++) {
							if (defined($complexGPR->{$complexes[$i]})) {
								for (my $m=0; $m < @{$complexGPR->{$complexes[$i]}}; $m++) {
									my $peg = $modelComplexes->{$complexes[$i]}->{"L"}->{$roles[$j]}->[$k];
									if ($complexGPR->{$complexes[$i]}->[$m] !~ m/$peg/) {
										push(@{$newGeneAssociations},$complexGPR->{$complexes[$i]}->[$m]."+".$peg);
									} else {
										push(@{$newGeneAssociations},$complexGPR->{$complexes[$i]}->[$m]);
									}
								}
							}
						}
						$complexGPR->{$complexes[$i]} = $newGeneAssociations;
					}
				}
			}
		}
	}
	#Translating the complex GPR into a reaction gpr
	my $reactionGPR;
	@complexes = keys(%{$complexGPR});
	for (my $i=0; $i < @complexes; $i++) {
		for (my $j=0; $j < @{$complexHash->{$complexes[$i]}}; $j++) {
			if (defined($complexGPR->{$complexes[$i]}->[0])) {
				push(@{$reactionGPR->{$complexHash->{$complexes[$i]}->[$j]}},@{$complexGPR->{$complexes[$i]}});
			}
		}
	}
	#Looking for colocalized gene associations we can combine into additional complexes
	if (defined($locations)) {
		#Putting the gene locations into a hash for the gene ids
		my $geneLocations;
		for (my $i=0; $i < @{$mapped_DNA}; $i++) {
			$geneLocations->{$mapped_DNA->[$i]} = $locations->[$i];
		}
		my @reactions = keys(%{$reactionGPR});
		for (my $i=0; $i < @reactions; $i++) {
			for (my $j=0; $j < @{$reactionGPR->{$reactions[$i]}}; $j++) {
				if (defined($reactionGPR->{$reactions[$i]}->[$j])) {
					my @geneList = split(/\+/,$reactionGPR->{$reactions[$i]}->[$j]);
					for (my $k=$j+1; $k < @{$reactionGPR->{$reactions[$i]}}; $k++) {
						if (defined($reactionGPR->{$reactions[$i]}->[$k])) {
							my @otherGeneList = split(/\+/,$reactionGPR->{$reactions[$i]}->[$k]);
							my $combine = 0;
							for (my $n=0; $n < @geneList; $n++) {
								my $neighbor = 0;
								my $match = 0;
								for (my $m=0; $m < @otherGeneList; $m++) {
									if ($geneList[$n] eq $otherGeneList[$m]) {
										$match = 1;
										last;
									} elsif (abs($geneLocations->{$geneList[$n]}-$geneLocations->{$otherGeneList[$m]}) < 5000) {
										$neighbor = 1;	
									}
								}
								if ($neighbor == 1 && $match == 0) {
									$combine = 1;
									last;
								}
							}
							#If a neighbor is found in the second set, we combine the sets
							if ($combine == 1) {
								my $geneHash;
								for (my $n=0; $n < @geneList; $n++) {
									$geneHash->{$geneList[$n]} = 1;
								}
								for (my $n=0; $n < @otherGeneList; $n++) {
									$geneHash->{$otherGeneList[$n]} = 1;
								}
								$reactionGPR->{$reactions[$i]}->[$j] = join("+",sort(keys(%{$geneHash})));
								@geneList = keys(%{$geneHash});
								splice(@{$reactionGPR->{$reactions[$i]}},$k,1);
								$k--;
							}
						}
					}
				}
			}
		}
	}
	#Ensuring that genes in complexes are sorted and never repeated
	my @reactions = keys(%{$reactionGPR});
	for (my $i=0; $i < @reactions; $i++) {
		for (my $j=0; $j < @{$reactionGPR->{$reactions[$i]}}; $j++) {
			my @genes = split(/\+/,$reactionGPR->{$reactions[$i]}->[$j]);
			my $genehash;
			for (my $k=0; $k < @genes; $k++) {
				$genehash->{$genes[$k]} =1;
			}
			$reactionGPR->{$reactions[$i]}->[$j] = join("+",sort(keys(%{$genehash})));
		}
	}
	#Returning the result
	return $reactionGPR;
}

=head3 ArchiveModel
Definition:
	(success/fail) = FIGMODELmodel->ArchiveModel();
Description:
	This function archives the specified model in the model directory with the current version numbers appended.
	This function is used to preserve old versions of models prior to overwriting so new versions may be compared with old versions.
=cut
sub ArchiveModel {
	my ($self) = @_;

	#Checking that the model file exists
	if (!(-e $self->filename())) {
		$self->figmodel()->error_message("FIGMODEL:ArchiveModel: Model file ".$self->filename()." not found!");
		return $self->figmodel()->fail();
	}

	#Copying the model file
	system("cp ".$self->filename()." ".$self->directory().$self->id().$self->version().".txt");
}

=head3 PrintModelDataToFile
Definition:
	(success/fail) = FIGMODELmodel->PrintModelDataToFile();
Description:
	This function uses the MFAToolkit to print out all of the compound and reaction data for the input model.
	Some of the data printed by the toolkit is calculated internally in the toolkit and not stored in any files, so this data can only be retrieved through this
	function. The LoadModel function for example would not give you this data.
=cut
sub PrintModelDataToFile {
	my($self) = @_;

	#Running the MFAToolkit on the model file
	my $OutputIndex = $self->figmodel()->filename();
	my $Command = $self->config("MFAToolkit executable")->[0]." parameterfile ../Parameters/Printing.txt resetparameter output_folder ".$OutputIndex.'/ LoadCentralSystem "'.$self->filename().'"';
	system($Command);

	#Copying the model file printed by the toolkit out of the output directory and into the model directory
	if (!-e $self->config("MFAToolkit output directory")->[0].$OutputIndex."/".$self->id().$self->selected_version().".txt") {
		$self->figmodel()->error_message("New model file not created due to an error. Check that the input modelfile exists.");
		$self->figmodel()->cleardirectory($OutputIndex);
		return $self->figmodel()->fail();
	}

	$Command = 'cp "'.$self->config("MFAToolkit output directory")->[0].$OutputIndex."/".$self->id().$self->selected_version().'.txt" "'.$self->directory().$self->id().$self->selected_version().'Data.txt"';
	system($Command);
	$Command = 'cp "'.$self->config("MFAToolkit output directory")->[0].$OutputIndex.'/ErrorLog0.txt" "'.$self->directory().'ModelErrors.txt"';
	system($Command);
	$self->figmodel()->cleardirectory($OutputIndex);
	return $self->figmodel()->success();
}
=head3 add_reactions
Definition:
    {} = FIGMODEL->add_reaction({
    	ids => [string],
    	directionalitys => [string],
    	compartments => [string],
    	pegs => [string],
    	subsystems => [string],
    	confidences => [string],
    	references => [string],
    	notes => [string],
    	reason => "NONE",
    	user => $self->figmodel()->user(),
    	adjustmentOnly => 1,
    	transaction => undef
    })
Description:
    Adds a reaction to the model and updates model statistics
=cut
sub add_reactions {
    my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["ids"],{
    	directionalitys => [],
    	compartments => [],
    	pegs => [[]],
    	subsystems => [[]],
    	confidences => [],
    	references => [[]],
    	notes => [[]],
    	reason => "NONE",
    	user => $self->figmodel()->user(),
    	adjustmentOnly => 1,
    	transaction => undef
	});	
	if (defined($args->{error})) {return $self->error_message({function => "add_reactions",args => $args});}
	my $transaction;
	$self->aquireModelLock();
    my $rxnTable = $self->reaction_table(1);
	for (my $i=0; $i < @{$args->{ids}}; $i++) {
		my $id = $args->{ids}->[$i];
		my $sign = $self->figmodel()->reversibility_of_reaction($id);
		if ($args->{ids}->[$i] =~ m/(.)(rxn\d+)/) {
			$id = $2;
			$sign = $1;
			if ($sign eq "-") {
				$sign = "<=";
			} elsif ($sign eq "+") {
				$sign = "=>";	
			}
		}
		if (defined($args->{directionality}->[$i])) {
			$sign = $args->{directionality}->[$i];
		}
		if (!defined($args->{compartment}->[$i])) {
			$args->{compartment}->[$i] = "c";
		}
		my $row;
		my @rows = $rxnTable->get_rows_by_key($id, 'LOAD');
	    for (my $j=0; $j < @rows; $j++) {
	    	if ($rows[$j]->{COMPARTMENT}->[0] eq $args->{compartment}->[$i]) {
	    		$row = $rows[$j];
	    		last;
	    	}
	    }
	    my $action = "added";
		if (defined($row) && $args->{adjustmentOnly} == 1) {
	    	if ($row->{DIRECTIONALITY}->[0] ne $sign) {
	    		$row->{DIRECTIONALITY}->[0] = "<=>";
	    	}
	    	if (defined($args->{subsystem}->[$i]->[0]) && $args->{subsystem}->[$i]->[0] ne "NONE") {
	    		$rxnTable->add_data($row,"SUBSYSTEM",$args->{subsystems}->[$i],1);
	    	}
	    	if (defined($args->{note}->[$i]->[0]) && $args->{note}->[$i]->[0] ne "NONE") {
	    		$rxnTable->add_data($row,"NOTES",$args->{note}->[$i],1);
	    	}
	    	if (defined($args->{reason}) && $args->{reason} ne "NONE") {
	    		$rxnTable->add_data($row,"NOTES",$args->{reason},1);
	    	}
	    	if (defined($args->{reference}->[$i]->[0]) && $args->{reference}->[$i]->[0] ne "NONE") {
	    		$rxnTable->add_data($row,"REFERENCE",$args->{reference}->[$i],1);
	    	}
	    	if (defined($args->{pegs}->[$i]->[0]) && $args->{pegs}->[$i]->[0] ne "UNKNOWN" && $args->{pegs}->[$i]->[0] ne "AUTOCOMPLETION") {
	    		$rxnTable->add_data($row,"ASSOCIATED PEG",$args->{pegs}->[$i],1);
	    	}
	    	$action = "adjusted";
	    } else {
	    	if (defined($row)) {
	    		my $rowId = $rxnTable->row_index($row);
	        	$rxnTable->delete_row($rowId);
	        	$action = "adjusted";
	    	}
	    	$row = {
	    		LOAD => [$id],
	    		COMPARTMENT => [$args->{compartment}->[$i]],
	    		DIRECTIONALITY => [$sign],
	    		"ASSOCIATED PEG" => $args->{pegs}->[$i],
	    		SUBSYSTEM => $args->{subsystems}->[$i],
	    		CONFIDENCE => [$args->{confidences}->[$i]],
	    		NOTES => $args->{notes}->[$i],
	    		REFERENCE => $args->{references}->[$i]
	    	};
	    	$rxnTable->add_row($row);
	    	if (defined($args->{reason}) && $args->{reason} ne "NONE") {
	    		$rxnTable->add_data($row,"NOTES",$args->{reason},1);
	    	}
	    }
	    # remove all rows that contain same id and compartment
		my $rxnObj = $self->figmodel()->database()->get_object('rxnmdl',{
			'REACTION' => $id,
			'MODEL' => $self->id(),
			'compartment' => $args->{compartment}->[$i]
		});
	    if(defined($rxnObj)) {
	        $rxnObj->delete();
	    }
	    $rxnObj = $self->figmodel()->database()->create_object('rxnmdl',{
	    	REACTION => $row->{LOAD}->[0],
			MODEL => $self->id(),
			directionality => $row->{DIRECTIONALITY}->[0],
			compartment => $row->{COMPARTMENT}->[0],
			pegs => join("|",@{$row->{"ASSOCIATED PEG"}}),
			confidence => $row->{CONFIDENCE}->[0]
	    });
	    if (!defined($args->{transaction})) {
	    	$args->{transaction} = $self->figmodel()->database()->create_object('mdlhisttrans',{
		    	cause => $args->{reason},
				user => $args->{user},
				modificationDate => time(),
				version => $self->version(),
				MODEL => $self->id()
	    	});
	    }
	    my $historyObj = $self->figmodel()->database()->create_object('mdlhist',{
		    TRANSACTION => $args->{transaction}->_id(),
			REACTION => $row->{LOAD}->[0],
			directionality => $row->{DIRECTIONALITY}->[0],
			compartment => $row->{COMPARTMENT}->[0],
			pegs => join("|",@{$row->{"ASSOCIATED PEG"}}),
			action => $action
	    });
	    if (defined($rxnObj) && defined($row->{REFERENCE}->[0]) && $row->{REFERENCE}->[0] ne "NONE") {
	    	for (my $i=0; $i < @{$row->{REFERENCE}}; $i++) {
		    	my $refID = "NONE";
		    	if ($row->{REFERENCE}->[$i] =~ m/^PMID\d+$/) {
		    		$refID = $row->{REFERENCE}->[$i];
		    	}
		    	my $rxnObj = $self->figmodel()->database()->create_object('reference',{
			    	objectID => $rxnObj->_id(),
					DBENTITY => "rxnmdl",
					pubmedID => "NONE",
					notation => $row->{REFERENCE}->[$i],
					date => time()
		    	});
	    	}
	    }
	}
	$rxnTable->save();
    $self->releaseModelLock();
    $self->reaction_table(1);
	#$self->processModel();
	return $args;
}
=head3 removeReactions
Definition:
	{}:Output = FIGMODELmodel->removeReactions({
		ids=>[string]:reaction IDs,
		compartments=>[string]:compartment, (defaults to c)
		reason=>string:reason for deletion, (defaults to NONE)
		user=>string:login of the user calling for the changes (defaults to model owner)
		trackChanges=>0/1:indicates if the transactions should be tracked (defaults to 1)
	});
	Output = {error=>string:error message} ({} returned on success)
Description:
=cut
sub removeReactions {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["ids"],{
		compartments=>[],
		reason=>"NONE",
		user=>$self->owner(),
		trackChanges=>1
	});
	if (defined($args->{error})) {return $self->error_message({function=>"removeReactions",args=>$args});}
	#Aquiring a lock on the reaction table for model
	$self->aquireModelLock();
	my $rxnTable = $self->reaction_table(1);
	$rxnTable->add_hashheadings(["COMPARTMENT"]);
	my $transaction;
	for (my $i=0; $i < @{$args->{ids}}; $i++) {
		my $deleted = 0;
		if (!defined($args->{compartments}->[$i])) {
			$args->{compartments}->[$i] = "c";
		}
		#Adjusting the PPO table
		my $rxnDB = $self->figmodel()->database()->get_object('rxnmdl',{
			REACTION => $args->{ids}->[$i],
			MODEL => $self->id(),
			compartment => $args->{compartments}->[$i]
		});
	    if(defined($rxnDB)) {
	        $rxnDB->delete();
	    }
	    #Deleting reaction table row 
	    my $direction = "NONE";
	    my $pegs = "NONE";
	    my $row;
		my @rows = $rxnTable->get_rows_by_key($args->{ids}->[$i], 'LOAD');
	    for (my $j=0; $j < @rows; $j++) {
	    	if ($rows[$j]->{COMPARTMENT}->[0] eq $args->{compartments}->[$i]) {
	    		$row = $rows[$j];
	    		$deleted = 1;
	            $direction = $row->{DIRECTIONALITY}->[0];
	            if (defined($row->{"ASSOCIATED PEG"}->[0])) {
	            	$pegs = join("|",@{$row->{"ASSOCIATED PEG"}});
	            }
	            $rxnTable->delete_row($rxnTable->row_index($row));
	    		last;
	    	}
	    }
	    #Saving transaction to transaction table
		if ($deleted == 1 && $args->{trackChanges} == 1) {
	        if (!defined($transaction)) {
	        	$transaction = $self->figmodel()->database()->create_object('mdlhisttrans',{
	        		cause=>$args->{reason},
	        		user=>$args->{user},
	        		MODEL=>$self->id(),
	        		version=>$self->version(),
	        		modificationDate=>time()
	        	});
	        }
	        $self->figmodel()->database()->create_object('mdlhist',{
        		TRANSACTION=>$transaction->_id(),
        		REACTION=>$args->{ids}->[$i],
        		directionality=>$direction,
        		compartment=>$args->{compartments}->[$i],
        		pegs=>$pegs,
        		action=>"deleted"
        	});
		}
	}
	#Saving the modified table
	$rxnTable->save();
	$self->releaseModelLock();
	$self->reaction_table(1);
	return {};
}
=head2 Analysis Functions

=head3 run_microarray_analysis
Definition:
	int::status = FIGMODEL->run_microarray_analysis(string::media,string::job id,string::gene calls);
Description:
	Runs microarray analysis attempting to turn off genes that are inactive in the microarray
=cut
sub run_microarray_analysis {
	my ($self,$media,$label,$index,$genecall) = @_;
	$genecall =~ s/_/:/g;
	$genecall =~ s/\//;/g;
	my $uniqueFilename = $self->figmodel()->filename();
	my $command = $self->figmodel()->GenerateMFAToolkitCommandLineCall($uniqueFilename,$self->id(),$media,["ProductionMFA","ShewenellaExperiment"],{"Microarray assertions" => $label.";".$index.";".$genecall,"MFASolver" => "CPLEX","Network output location" => "/scratch/"},"MicroarrayAnalysis-".$uniqueFilename.".txt",undef,$self->selected_version());
	system($command);
	my $filename = $self->figmodel()->config("MFAToolkit output directory")->[0].$uniqueFilename."/MicroarrayOutput-".$index.".txt";
	if (-e $filename) {
		my $output = $self->figmodel()->database()->load_single_column_file($filename);
		if (defined($output->[0])) {
			my @array = split(/;/,$output->[0]);
			$self->figmodel()->clearing_output($uniqueFilename,"MicroarrayAnalysis-".$uniqueFilename.".txt");
			return ($array[0],$array[1],$array[8].":".$array[2],$array[9].":".$array[3],$array[10].":".$array[4],$array[11].":".$array[5],$array[12].":".$array[6],$array[13].":".$array[7]);	
		}
		print STDERR $filename." is empty!";
	}
	print STDERR $filename." not found!";
	$self->figmodel()->clearing_output($uniqueFilename,"MicroarrayAnalysis-".$uniqueFilename.".txt");
	
	return undef;
}

=head3 find_minimal_pathways
Definition:
	int::status = FIGMODEL->find_minimal_pathways(string::media,string::objective);
Description:
	Runs microarray analysis attempting to turn off genes that are inactive in the microarray
=cut
sub find_minimal_pathways {
	my ($self,$media,$objective,$solutionnum,$AllReversible,$additionalexchange) = @_;

	#Setting default media
	if (!defined($media)) {
		$media = "Complete";
	}

	#Setting default solution number
	if (!defined($solutionnum)) {
		$solutionnum = "5";
	}

	#Setting additional exchange fluxes
	if (!defined($additionalexchange) || length($additionalexchange) == 0) {
		if ($self->id() eq "iAF1260") {
			$additionalexchange = "cpd03422[c]:-100:100;cpd01997[c]:-100:100;cpd11416[c]:-100:0;cpd15378[c]:-100:0;cpd15486[c]:-100:0";
		} else {
			$additionalexchange = $self->figmodel()->config("default exchange fluxes")->[0];
		}
	}

	#Translating objective
	my $objectivestring;
	if ($objective eq "ALL") {
		#Getting the list of universal building blocks
		my $buildingblocks = $self->config("universal building blocks");
		my @objectives = keys(%{$buildingblocks});
		#Getting the nonuniversal building blocks
		my $otherbuildingblocks = $self->config("nonuniversal building blocks");
		my @array = keys(%{$otherbuildingblocks});
		if (defined($self->get_biomass()) && defined($self->figmodel()->get_reaction($self->get_biomass()->{"LOAD"}->[0]))) {
			my $equation = $self->figmodel()->get_reaction($self->get_biomass()->{"LOAD"}->[0])->{"EQUATION"}->[0];
			if (defined($equation)) {
				for (my $i=0; $i < @array; $i++) {
					if (CORE::index($equation,$array[$i]) > 0) {
						push(@objectives,$array[$i]);
					}
				}
			}
		}
		for (my $i=0; $i < @objectives; $i++) {
			$self->find_minimal_pathways($media,$objectives[$i]);
		}
		return;
	} elsif ($objective eq "ENERGY") {
		$objectivestring = "MAX;FLUX;rxn00062;c;1";
	} elsif ($objective =~ m/cpd\d\d\d\d\d/) {
		if ($objective =~ m/\[(\w)\]/) {
			$objectivestring = "MIN;DRAIN_FLUX;".$objective.";".$1.";1";
			$additionalexchange .= ";".$objective."[".$1."]:-100:0";
		} else {
			$objectivestring = "MIN;DRAIN_FLUX;".$objective.";c;1";
			$additionalexchange .= ";".$objective."[c]:-100:0";
		}
	} elsif ($objective =~ m/(rxn\d\d\d\d\d)/) {
		my ($Reactants,$Products) = $self->figmodel()->GetReactionSubstrateData($objective);
		for (my $i=0; $i < @{$Products};$i++) {
			my $temp = $Products->[$i]->{"DATABASE"}->[0];
			if ($additionalexchange !~ m/$temp/) {
				#$additionalexchange .= ";".$temp."[c]:-100:0";
			}
		}
		for (my $i=0; $i < @{$Reactants};$i++) {
			print $Reactants->[$i]->{"DATABASE"}->[0]." started\n";
			$self->find_minimal_pathways($media,$Reactants->[$i]->{"DATABASE"}->[0],$additionalexchange);
			print $Reactants->[$i]->{"DATABASE"}->[0]." done\n";
		}
		return;
	}

	#Adding additional drains
	if (($objective eq "cpd15665" || $objective eq "cpd15667" || $objective eq "cpd15668" || $objective eq "cpd15669") && $additionalexchange !~ m/cpd15666/) {
		$additionalexchange .= ";cpd15666[c]:0:100";
	} elsif ($objective eq "cpd11493" && $additionalexchange !~ m/cpd12370/) {
		$additionalexchange .= ";cpd12370[c]:0:100";
	} elsif ($objective eq "cpd00166" && $additionalexchange !~ m/cpd01997/) {
		$additionalexchange .= ";cpd01997[c]:0:100;cpd03422[c]:0:100";
	}

	#Running MFAToolkit
	my $filename = $self->figmodel()->filename();
	my $command;
	if (defined($AllReversible) && $AllReversible == 1) {
		$command = $self->figmodel()->GenerateMFAToolkitCommandLineCall($filename,$self->id(),$media,["ProductionMFA"],{"Make all reactions reversible in MFA"=>1, "Recursive MILP solution limit" => $solutionnum,"Generate pathways to objective" => 1,"MFASolver" => "CPLEX","objective" => $objectivestring,"exchange species" => $additionalexchange},"MinimalPathways-".$media."-".$self->id().$self->selected_version().".txt",undef,$self->selected_version());
	} else {
		$command = $self->figmodel()->GenerateMFAToolkitCommandLineCall($filename,$self->id(),$media,["ProductionMFA"],{"Make all reactions reversible in MFA"=>0, "Recursive MILP solution limit" => $solutionnum,"Generate pathways to objective" => 1,"MFASolver" => "CPLEX","objective" => $objectivestring,"exchange species" => $additionalexchange},"MinimalPathways-".$media."-".$self->id().$self->selected_version().".txt",undef,$self->selected_version());
	}
	system($command);

	#Loading problem report
	my $results = $self->figmodel()->LoadProblemReport($filename);
	#Clearing output
	$self->figmodel()->clearing_output($filename,"MinimalPathways-".$media."-".$self->id()."-".$objective.".txt");
	if (!defined($results)) {
		print STDERR $objective." pathway results not found!\n";
		return;
	}

	#Parsing output
	my @Array;
	my $row = $results->get_row(1);
	if (defined($row->{"Notes"}->[0])) {
		$_ = $row->{"Notes"}->[0];
		@Array = /\d+:([^\|]+)\|/g;
	}
	
	#Writing output to file
	$self->figmodel()->database()->print_array_to_file($self->directory()."MinimalPathways-".$media."-".$objective."-".$self->id()."-".$AllReversible."-".$self->selected_version().".txt",[join("|",@Array)]);
}

=head3 find_minimal_pathways
Definition:
	int::status = FIGMODEL->find_minimal_pathways(string::media,string::objective);
Description:
	Runs microarray analysis attempting to turn off genes that are inactive in the microarray
=cut
sub find_minimal_pathways_two {
	my ($self,$media,$objective,$solutionnum,$AllReversible,$additionalexchange) = @_;

	#Setting default media
	if (!defined($media)) {
		$media = "Complete";
	}

	#Setting default solution number
	if (!defined($solutionnum)) {
		$solutionnum = "5";
	}

	#Setting additional exchange fluxes
	if (!defined($additionalexchange) || length($additionalexchange) == 0) {
		if ($self->id() eq "iAF1260") {
			$additionalexchange = "cpd03422[c]:-100:100;cpd01997[c]:-100:100;cpd11416[c]:-100:0;cpd15378[c]:-100:0;cpd15486[c]:-100:0";
		} else {
			$additionalexchange = $self->figmodel()->config("default exchange fluxes")->[0];
		}
	}

	#Translating objective
	my $objectivestring;
	if ($objective eq "ALL") {
		#Getting the list of universal building blocks
		my $buildingblocks = $self->config("universal building blocks");
		my @objectives = keys(%{$buildingblocks});
		#Getting the nonuniversal building blocks
		my $otherbuildingblocks = $self->config("nonuniversal building blocks");
		my @array = keys(%{$otherbuildingblocks});
		if (defined($self->get_biomass()) && defined($self->figmodel()->get_reaction($self->get_biomass()->{"LOAD"}->[0]))) {
			my $equation = $self->figmodel()->get_reaction($self->get_biomass()->{"LOAD"}->[0])->{"EQUATION"}->[0];
			if (defined($equation)) {
				for (my $i=0; $i < @array; $i++) {
					if (CORE::index($equation,$array[$i]) > 0) {
						push(@objectives,$array[$i]);
					}
				}
			}
		}
		for (my $i=0; $i < @objectives; $i++) {
			$self->find_minimal_pathways($media,$objectives[$i]);
		}
		return;
	} elsif ($objective eq "ENERGY") {
		$objectivestring = "MAX;FLUX;rxn00062;c;1";
	} elsif ($objective =~ m/cpd\d\d\d\d\d/) {
		if ($objective =~ m/\[(\w)\]/) {
			$objectivestring = "MIN;DRAIN_FLUX;".$objective.";".$1.";1";
			$additionalexchange .= ";".$objective."[".$1."]:-100:0";
		} else {
			$objectivestring = "MIN;DRAIN_FLUX;".$objective.";c;1";
			$additionalexchange .= ";".$objective."[c]:-100:0";
		}
	} elsif ($objective =~ m/(rxn\d\d\d\d\d)/) {
		my ($Reactants,$Products) = $self->figmodel()->GetReactionSubstrateData($objective);
		for (my $i=0; $i < @{$Products};$i++) {
			my $temp = $Products->[$i]->{"DATABASE"}->[0];
			if ($additionalexchange !~ m/$temp/) {
				#$additionalexchange .= ";".$temp."[c]:-100:0";
			}
		}
		for (my $i=0; $i < @{$Reactants};$i++) {
			print $Reactants->[$i]->{"DATABASE"}->[0]." started\n";
			$self->find_minimal_pathways($media,$Reactants->[$i]->{"DATABASE"}->[0],$additionalexchange);
			print $Reactants->[$i]->{"DATABASE"}->[0]." done\n";
		}
		return;
	}

	#Adding additional drains
	if (($objective eq "cpd15665" || $objective eq "cpd15667" || $objective eq "cpd15668" || $objective eq "cpd15669") && $additionalexchange !~ m/cpd15666/) {
		$additionalexchange .= ";cpd15666[c]:0:100";
	} elsif ($objective eq "cpd11493" && $additionalexchange !~ m/cpd12370/) {
		$additionalexchange .= ";cpd12370[c]:0:100";
	} elsif ($objective eq "cpd00166" && $additionalexchange !~ m/cpd01997/) {
		$additionalexchange .= ";cpd01997[c]:0:100;cpd03422[c]:0:100";
	}

	#Running MFAToolkit
	my $filename = $self->figmodel()->filename();
	my $command;
	if (defined($AllReversible) && $AllReversible == 1) {
		$command = $self->figmodel()->GenerateMFAToolkitCommandLineCall($filename,$self->id(),$media,["ProductionMFA"],{"use simple variable and constraint names"=>1,"Make all reactions reversible in MFA"=>1, "Recursive MILP solution limit" => $solutionnum,"Generate pathways to objective" => 1,"MFASolver" => "SCIP","objective" => $objectivestring,"exchange species" => $additionalexchange},"MinimalPathways-".$media."-".$self->id().$self->selected_version().".txt",undef,$self->selected_version());
	} else {
		$command = $self->figmodel()->GenerateMFAToolkitCommandLineCall($filename,$self->id(),$media,["ProductionMFA"],{"use simple variable and constraint names"=>1,"Make all reactions reversible in MFA"=>0, "Recursive MILP solution limit" => $solutionnum,"Generate pathways to objective" => 1,"MFASolver" => "SCIP","objective" => $objectivestring,"exchange species" => $additionalexchange},"MinimalPathways-".$media."-".$self->id().$self->selected_version().".txt",undef,$self->selected_version());
	}
	print $command."\n";
	system($command);

	#Loading problem report
	my $results = $self->figmodel()->LoadProblemReport($filename);
	#Clearing output
	$self->figmodel()->clearing_output($filename,"MinimalPathways-".$media."-".$self->id()."-".$objective.".txt");
	if (!defined($results)) {
		print STDERR $objective." pathway results not found!\n";
		return;
	}

	#Parsing output
	my @Array;
	my $row = $results->get_row(1);
	if (defined($row->{"Notes"}->[0])) {
		$_ = $row->{"Notes"}->[0];
		@Array = /\d+:([^\|]+)\|/g;
	}
	
	#Writing output to file
	$self->figmodel()->database()->print_array_to_file($self->directory()."MinimalPathways-".$media."-".$objective."-".$self->id()."-".$AllReversible."-".$self->selected_version().".txt",[join("|",@Array)]);
}

sub combine_minimal_pathways {
	my ($self) = @_;
	
	my $tbl;
	if (-e $self->directory()."MinimalPathwayTable-".$self->id().$self->selected_version().".tbl") {
		$tbl = ModelSEED::FIGMODEL::FIGMODELTable::load_table($self->directory()."MinimalPathwayTable-".$self->id().$self->selected_version().".tbl",";","|",0,["Objective","Media","Reversible"]);
	} else {
		$tbl = ModelSEED::FIGMODEL::FIGMODELTable->new(["Objective","Media","Reactions","Reversible","Shortest path","Number of essentials","Essentials","Length"],$self->directory()."MinimalPathwayTable-".$self->id().$self->selected_version().".tbl",["Objective","Media","Reversible"],";","|");
	}
	my @files = glob($self->directory()."MinimalPathways-*");
	for (my $i=0; $i < @files;$i++) {
		if ($files[$i] =~ m/MinimalPathways\-(\S+)\-(cpd\d\d\d\d\d)\-(\w+)\-(\d)\-/ || $files[$i] =~ m/MinimalPathways\-(\S+)\-(ENERGY)\-(\w+)\-(\d)\-/) {
			my $reactions = $self->figmodel()->database()->load_single_column_file($files[$i],"");
			if (defined($reactions) && @{$reactions} > 0 && length($reactions->[0]) > 0) {
				my $newrow = {"Objective"=>[$2],"Media"=>[$1],"Reversible"=>[$4]};
				my $row = $tbl->get_table_by_key($newrow->{"Objective"}->[0],"Objective")->get_table_by_key($newrow->{"Media"}->[0],"Media")->get_row_by_key($newrow->{"Reversible"}->[0],"Reversible");
				if (!defined($row)) {
					$row = $tbl->add_row($newrow);
				}
				$row->{Reactions} = $self->figmodel()->database()->load_single_column_file($files[$i],"");
				delete($row->{"Shortest path"});
				delete($row->{"Number of essentials"});
				delete($row->{"Essentials"});
				delete($row->{"Length"});
				for (my $j=0; $j < @{$row->{Reactions}}; $j++) {
					my @array = split(/,/,$row->{Reactions}->[$j]);
					$row->{"Length"}->[$j] = @array;
					if (!defined($row->{"Shortest path"}->[0]) || $row->{"Length"}->[$j] < $row->{"Shortest path"}->[0]) {
						$row->{"Shortest path"}->[0] = $row->{"Length"}->[$j];
					}
					$row->{"Number of essentials"}->[0] = 0;
					for (my $k=0; $k < @array;$k++) {
						if ($array[$k] =~ m/(rxn\d\d\d\d\d)/) {
							my $class = $self->get_reaction_class($1,1);
							my $temp = $row->{Media}->[0].":Essential";
							if ($class =~ m/$temp/) {
								$row->{"Number of essentials"}->[$j]++;
								if (!defined($row->{"Essentials"}->[$j]) && length($row->{"Essentials"}->[$j]) > 0) {
									$row->{"Essentials"}->[$j] = $array[$k];
								} else {
									$row->{"Essentials"}->[$j] .= ",".$array[$k];
								}
							}
						}
					}
				}
			}
		}
	}
	$tbl->save();	
}

=head3 RunAllStudiesWithDataFast
Definition:
	(integer::false positives,integer::false negatives,integer::correct negatives,integer::correct positives,string::error vector,string heading vector) = FIGMODELmodel->RunAllStudiesWithDataFast(string::experiment,0/1::print result);
Description:
	Simulates every experimental condition currently available for the model.
=cut

sub RunAllStudiesWithDataFast {
	my ($self,$Experiment,$PrintResults) = @_;

	#Printing lp and key file for model
	if (!-e $self->directory()."FBA-".$self->id().$self->selected_version().".lp") {
		$self->PrintModelLPFile();
	}
	my $UniqueFilename = $self->figmodel()->filename();

	#Determing the simulations that need to be run
	my $ExperimentalDataTable = $self->figmodel()->GetExperimentalDataTable($self->genome(),$Experiment);
	#Creating the table of jobs to submit
	my $JobArray = $self->GetSimulationJobTable($ExperimentalDataTable,$Experiment,$UniqueFilename);
	#Printing the job file
	if (!-d $self->config("MFAToolkit output directory")->[0].$UniqueFilename."/") {
		system("mkdir ".$self->config("MFAToolkit output directory")->[0].$UniqueFilename."/");
	}
	$JobArray->save();

	#Running simulations
	system($self->config("mfalite executable")->[0]." ".$self->config("Reaction database directory")->[0]."masterfiles/MediaTable.txt ".$self->config("MFAToolkit output directory")->[0].$UniqueFilename."/Jobfile.txt ".$self->config("MFAToolkit output directory")->[0].$UniqueFilename."/Output.txt");
	#Parsing the results
	my $Results = $self->figmodel()->database()->load_table($self->config("MFAToolkit output directory")->[0].$UniqueFilename."/Output.txt",";","\\|",0,undef);
	if (!defined($Results)) {
		$self->figmodel()->error_message("FIGMODELmodel:RunAllStudiesWithDataFast:Could not find simulation results: ".$self->config("MFAToolkit output directory")->[0].$UniqueFilename."/Output.txt");
		return undef;
	}
	my ($FalsePostives,$FalseNegatives,$CorrectNegatives,$CorrectPositives,$Errorvector,$HeadingVector,$SimulationResults) = $self->EvaluateSimulationResults($Results,$ExperimentalDataTable);
	#Printing results to file
	$self->figmodel()->database()->save_table($SimulationResults,undef,undef,undef,"False negatives\tFalse positives\tCorrect negatives\tCorrect positives\n".$FalseNegatives."\t".$FalsePostives."\t".$CorrectNegatives."\t".$CorrectPositives."\n");
	$self->figmodel()->clearing_output($UniqueFilename);

	return ($FalsePostives,$FalseNegatives,$CorrectNegatives,$CorrectPositives,$Errorvector,$HeadingVector);
}

=head3 GetSimulationJobTable
Definition:
	my $JobTable = $model->GetSimulationJobTable($Experiment,$PrintResults,$Version);
Description:
=cut

sub GetSimulationJobTable {
	my ($self,$SimulationTable,$Experiment,$Folder) = @_;

	#Determing the simulations that need to be run
	if (!defined($SimulationTable)) {
		$SimulationTable = $self->figmodel()->GetExperimentalDataTable($self->genome(),$Experiment);
		if (!defined($SimulationTable)) {
			return undef;
		}
	}

	#Creating the job table
	my $JobTable = $self->figmodel()->CreateJobTable($Folder);
	for (my $i=0; $i < $SimulationTable->size(); $i++) {
		if ($SimulationTable->get_row($i)->{"Heading"}->[0] =~ m/Gene\sKO/) {
			my $Row = $JobTable->get_row_by_key("Gene KO","LABEL",1);
			$JobTable->add_data($Row,"MEDIA",$SimulationTable->get_row($i)->{"Media"}->[0],1);
		} elsif ($SimulationTable->get_row($i)->{"Heading"}->[0] =~ m/Media\sgrowth/) {
			my $Row = $JobTable->get_row_by_key("Growth phenotype","LABEL",1);
			$JobTable->add_data($Row,"MEDIA",$SimulationTable->get_row($i)->{"Media"}->[0],1);
		} elsif ($SimulationTable->get_row($i)->{"Heading"}->[0] =~ m/Interval\sKO/) {
			my $Row = $JobTable->get_row_by_key($SimulationTable->get_row($i)->{"Heading"}->[0],"LABEL",1);
			$JobTable->add_data($Row,"MEDIA",$SimulationTable->get_row($i)->{"Media"}->[0],1);
			$JobTable->add_data($Row,"GENE KO",$SimulationTable->get_row($i)->{"Experiment type"}->[0],1);
		}
	}

	#Filling in model specific elements of the job table
	for (my $i=0; $i < $JobTable->size(); $i++) {
		if ($JobTable->get_row($i)->{"LABEL"}->[0] =~ m/Gene\sKO/) {
			$JobTable->get_row($i)->{"RUNTYPE"}->[0] = "SINGLEKO";
			$JobTable->get_row($i)->{"SAVE NONESSENTIALS"}->[0] = 1;
		} else {
			$JobTable->get_row($i)->{"RUNTYPE"}->[0] = "GROWTH";
			$JobTable->get_row($i)->{"SAVE NONESSENTIALS"}->[0] = 0;
		}
		$JobTable->get_row($i)->{"LP FILE"}->[0] = $self->directory()."FBA-".$self->id().$self->selected_version();
		$JobTable->get_row($i)->{"MODEL"}->[0] = $self->directory().$self->id().$self->selected_version().".txt";
		$JobTable->get_row($i)->{"SAVE FLUXES"}->[0] = 0;
	}

	return $JobTable;
}

=head3 EvaluateSimulationResults
Definition:
	(integer::false positives,integer::false negatives,integer::correct negatives,integer::correct positives,string::error vector,string heading vector,FIGMODELtable::simulation results) = FIGMODELmodel->EvaluateSimulationResults(FIGMODELtable::raw simulation results,FIGMODELtable::experimental data);
Description:
	Compares simulation results with experimental data to produce a table indicating where predictions are incorrect.
=cut

sub EvaluateSimulationResults {
	my ($self,$Results,$ExperimentalDataTable) = @_;

	#Comparing experimental results with simulation results
	my $SimulationResults = ModelSEED::FIGMODEL::FIGMODELTable->new(["Run result","Experiment type","Media","Experiment ID","Reactions knocked out"],$self->directory()."SimulationOutput".$self->id().$self->selected_version().".txt",["Experiment ID","Media"],"\t",",",undef);
	my $FalsePostives = 0;
	my $FalseNegatives = 0;
	my $CorrectNegatives = 0;
	my $CorrectPositives = 0;
	my @Errorvector;
	my @HeadingVector;
	my $ReactionKOWithGeneHash;
	for (my $i=0; $i < $Results->size(); $i++) {
		if ($Results->get_row($i)->{"LABEL"}->[0] eq "Gene KO") {
			if (defined($Results->get_row($i)->{"REACTION KO WITH GENES"})) {
				for (my $j=0; $j < @{$Results->get_row($i)->{"REACTION KO WITH GENES"}}; $j++) {
					my @Temp = split(/:/,$Results->get_row($i)->{"REACTION KO WITH GENES"}->[$j]);
					if (defined($Temp[1]) && length($Temp[1]) > 0) {
						$ReactionKOWithGeneHash->{$Temp[0]} = $Temp[1];
					}
				}
			}
			if ($Results->get_row($i)->{"OBJECTIVE"}->[0] == 0) {
				for (my $j=0; $j < @{$Results->get_row($i)->{"NONESSENTIALGENES"}}; $j++) {
					my $Row = $ExperimentalDataTable->get_row_by_key("Gene KO:".$Results->get_row($i)->{"MEDIA"}->[0].":".$Results->get_row($i)->{"NONESSENTIALGENES"}->[$j],"Heading");
					if (defined($Row)) {
						my $KOReactions = "none";
						if (defined($ReactionKOWithGeneHash->{$Results->get_row($i)->{"NONESSENTIALGENES"}->[$j]})) {
							$KOReactions = $ReactionKOWithGeneHash->{$Results->get_row($i)->{"NONESSENTIALGENES"}->[$j]};
						}
						push(@HeadingVector,$Row->{"Heading"}->[0].":".$KOReactions);
						my $Status = "Unknown";
						if ($Row->{"Growth"}->[0] > 0) {
							$Status = "False negative";
							$FalseNegatives++;
							push(@Errorvector,3);
						} else {
							$Status = "False positive";
							$FalsePostives++;
							push(@Errorvector,2);
						}
						$SimulationResults->add_row({"Run result" => [$Status],"Experiment type" => ["Gene KO"],"Media" => [$Row->{"Media"}->[0]],"Experiment ID" => [$Row->{"Experiment ID"}->[0]],"Reactions knocked out" => [$KOReactions]});
					}
				}
			} else {
				for (my $j=0; $j < @{$Results->get_row($i)->{"ESSENTIALGENES"}}; $j++) {
					#print $j."\t".$Results->get_row($i)->{"ESSENTIALGENES"}->[$j]."\n";
					my $Row = $ExperimentalDataTable->get_row_by_key("Gene KO:".$Results->get_row($i)->{"MEDIA"}->[0].":".$Results->get_row($i)->{"ESSENTIALGENES"}->[$j],"Heading");
					if (defined($Row)) {
						my $KOReactions = "none";
						if (defined($ReactionKOWithGeneHash->{$Results->get_row($i)->{"ESSENTIALGENES"}->[$j]})) {
							$KOReactions = $ReactionKOWithGeneHash->{$Results->get_row($i)->{"ESSENTIALGENES"}->[$j]};
						}
						push(@HeadingVector,$Row->{"Heading"}->[0].":".$KOReactions);
						my $Status = "Unknown";
						if ($Row->{"Growth"}->[0] > 0) {
							$Status = "False negative";
							$FalseNegatives++;
							push(@Errorvector,3);
						} else {
							$Status = "Correct negative";
							$CorrectNegatives++;
							push(@Errorvector,1);
						}
						$SimulationResults->add_row({"Run result" => [$Status],"Experiment type" => ["Gene KO"],"Media" => [$Row->{"Media"}->[0]],"Experiment ID" => [$Row->{"Experiment ID"}->[0]],"Reactions knocked out" => [$KOReactions]});
					}
				}
				for (my $j=0; $j < @{$Results->get_row($i)->{"NONESSENTIALGENES"}}; $j++) {
					my $Row = $ExperimentalDataTable->get_row_by_key("Gene KO:".$Results->get_row($i)->{"MEDIA"}->[0].":".$Results->get_row($i)->{"NONESSENTIALGENES"}->[$j],"Heading");
					if (defined($Row)) {
						my $KOReactions = "none";
						if (defined($ReactionKOWithGeneHash->{$Results->get_row($i)->{"NONESSENTIALGENES"}->[$j]})) {
							$KOReactions = $ReactionKOWithGeneHash->{$Results->get_row($i)->{"NONESSENTIALGENES"}->[$j]};
						}
						push(@HeadingVector,$Row->{"Heading"}->[0].":".$KOReactions);
						my $Status = "Unknown";
						if ($Row->{"Growth"}->[0] > 0) {
							$Status = "Correct positive";
							$CorrectPositives++;
							push(@Errorvector,0);
						} else {
							$Status = "False positive";
							$FalsePostives++;
							push(@Errorvector,2);
						}
						$SimulationResults->add_row({"Run result" => [$Status],"Experiment type" => ["Gene KO"],"Media" => [$Row->{"Media"}->[0]],"Experiment ID" => [$Row->{"Experiment ID"}->[0]],"Reactions knocked out" => [$KOReactions]});
					}
				}
			}
		} elsif ($Results->get_row($i)->{"LABEL"}->[0] eq "Growth phenotype") {
			my $Row = $ExperimentalDataTable->get_row_by_key("Media growth:".$Results->get_row($i)->{"MEDIA"}->[0].":".$Results->get_row($i)->{"MEDIA"}->[0],"Heading");
			if (defined($Row)) {
				push(@HeadingVector,$Row->{"Heading"}->[0].":none");
				my $Status = "Unknown";
				if ($Row->{"Growth"}->[0] > 0) {
					if ($Results->get_row($i)->{"OBJECTIVE"}->[0] > 0) {
						$Status = "Correct positive";
						$CorrectPositives++;
						push(@Errorvector,0);
					} else {
						$Status = "False negative";
						$FalseNegatives++;
						push(@Errorvector,3);
					}
				} else {
					if ($Results->get_row($i)->{"OBJECTIVE"}->[0] > 0) {
						$Status = "False positive";
						$FalsePostives++;
						push(@Errorvector,2);
					} else {
						$Status = "Correct negative";
						$CorrectNegatives++;
						push(@Errorvector,1);
					}
				}
				$SimulationResults->add_row({"Run result" => [$Status],"Experiment type" => ["Media growth"],"Media" => [$Row->{"Media"}->[0]],"Experiment ID" => [$Row->{"Media"}->[0]],"Reactions knocked out" => ["none"]});
			}
		} elsif ($Results->get_row($i)->{"LABEL"}->[0] =~ m/Interval\sKO/ && defined($Results->get_row($i)->{"KOGENES"}->[0])) {
			my $Row = $ExperimentalDataTable->get_row_by_key($Results->get_row($i)->{"LABEL"}->[0],"Heading");
			if (defined($Row)) {
				my $Status = "Unknown";
				if ($Row->{"Growth"}->[0] > 0) {
					if ($Results->get_row($i)->{"OBJECTIVE"}->[0] > 0) {
						$Status = "Correct positive";
						$CorrectPositives++;
						push(@Errorvector,0);
					} else {
						$Status = "False negative";
						$FalseNegatives++;
						push(@Errorvector,3);
					}
				} else {
					if ($Results->get_row($i)->{"OBJECTIVE"}->[0] > 0) {
						$Status = "False positive";
						$FalsePostives++;
						push(@Errorvector,2);
					} else {
						$Status = "Correct negative";
						$CorrectNegatives++;
						push(@Errorvector,1);
					}
				}
				$SimulationResults->add_row({"Run result" => [$Status],"Experiment type" => ["Interval KO"],"Media" => [$Row->{"Media"}->[0]],"Experiment ID" => [$Row->{"Experiment ID"}->[0]],"Reactions knocked out" => ["none"]});
			}
		}
	}

	return ($FalsePostives,$FalseNegatives,$CorrectNegatives,$CorrectPositives,join(";",@Errorvector),join(";",@HeadingVector),$SimulationResults);
}

=head3 InspectSolution
Definition:
	$model->InspectSolution(string::gene knocked out,string::media condition,[string]::list of reactions);
Description:
=cut

sub InspectSolution {
	my ($self,$GeneKO,$Media,$ReactionList) = @_;

	#Getting a directory for the results
	my $UniqueFilename = $self->figmodel()->filename();
	system("mkdir ".$self->config("MFAToolkit output directory")->[0].$UniqueFilename."/");
	my $TempVersion = "V".$UniqueFilename;

	#Setting gene ko to none if no genes are to be knocked out
	if ($GeneKO !~ m/^peg\./) {
		$GeneKO = "none";
	}

	#Implementing the input solution in the test model
	my $ReactionArray;
	my $DirectionArray;
	my %SolutionHash;
	for (my $k=0; $k < @{$ReactionList}; $k++) {
		if ($ReactionList->[$k] =~ m/(.+)(rxn\d\d\d\d\d)/) {
			my $Reaction = $2;
			my $Sign = $1;
			if (defined($SolutionHash{$Reaction})) {
				$SolutionHash{$Reaction} = "<=>";
			} elsif ($Sign eq "-") {
				$SolutionHash{$Reaction} = "<=";
			} elsif ($Sign eq "+") {
				$SolutionHash{$Reaction} = "=>";
			} else {
				$SolutionHash{$Reaction} = $Sign;
			}
		}
	}
	my @TempList = keys(%SolutionHash);
	for (my $k=0; $k < @TempList; $k++) {
		push(@{$ReactionArray},$TempList[$k]);
		push(@{$DirectionArray},$SolutionHash{$TempList[$k]});
	}

	print "Integrating solution!\n";
	$self->figmodel()->IntegrateGrowMatchSolution($self->id().$self->selected_version(),$self->directory().$self->id().$TempVersion.".txt",$ReactionArray,$DirectionArray,"SolutionInspection",1,1);

	#Printing lp and key file for model
	$self->PrintModelLPFile();

	#Running FBA on the test model
	my $JobTable = $self->figmodel()->CreateJobTable($UniqueFilename);
	$JobTable->add_row({"LABEL" => ["TEST"],"RUNTYPE" => ["GROWTH"],"LP FILE" => [$self->directory()."FBA-".$self->id().$TempVersion],"MODEL" => [$self->directory().$self->id().$TempVersion.".txt"],"MEDIA" => [$Media],"REACTION KO" => ["none|".join("|",@{$ReactionList})],"GENE KO" => [$GeneKO],"SAVE FLUXES" => [0],"SAVE NONESSENTIALS" => [0]});
	$JobTable->save();

	#Running simulations
	system($self->config("mfalite executable")->[0]." ".$self->config("Reaction database directory")->[0]."masterfiles/MediaTable.txt ".$self->config("MFAToolkit output directory")->[0].$UniqueFilename."/Jobfile.txt ".$self->config("MFAToolkit output directory")->[0].$UniqueFilename."/Output.txt");

	#Parsing the results
	my $Results = $self->figmodel()->database()->load_table($self->config("MFAToolkit output directory")->[0].$UniqueFilename."/Output.txt",";","\\|",0,undef);
	if (!defined($Results)) {
		$self->figmodel()->error_message("FIGMODELmodel:InspectSolution:Could not load problem report ".$self->config("MFAToolkit output directory")->[0].$UniqueFilename."/Output.txt");
		return undef;
	}

	#Making sure that the model grew with all reactions present
	my $Found = 0;
	for (my $i=0; $i < $Results->size(); $i++) {
		if (defined($Results->get_row($i)->{"KOGENES"}->[0]) && defined($Results->get_row($i)->{"KOREACTIONS"}->[0]) && $Results->get_row($i)->{"KOREACTIONS"}->[0] eq "none" && $Results->get_row($i)->{"KOGENES"}->[0] eq $GeneKO && $Results->get_row($i)->{"OBJECTIVE"}->[0] > 0.00001) {
			$Found = 1;
		}
	}
	if ($Found == 0) {
		print "Solution no longer valid\n";
		return undef;
	}

	#Making sure all of the reactions added are still necessary
	my $FinalReactionList;
	for (my $k=0; $k < $Results->size(); $k++) {
		if (defined($Results->get_row($k)->{"KOGENES"}->[0]) && $Results->get_row($k)->{"KOGENES"}->[0] eq $GeneKO) {
			if (defined($Results->get_row($k)->{"KOREACTIONS"}->[0]) && $Results->get_row($k)->{"KOREACTIONS"}->[0] =~ m/rxn\d\d\d\d\d/ && $Results->get_row($k)->{"OBJECTIVE"}->[0] < 0.000001) {
				push(@{$FinalReactionList},$Results->get_row($k)->{"KOREACTIONS"}->[0]);
			}
		}
	}

	#Deleting extra files created
	unlink($self->directory()."FBA-".$self->id().$TempVersion.".lp");
	unlink($self->directory()."FBA-".$self->id().$TempVersion.".key");
	unlink($self->directory().$self->id().$TempVersion.".txt");

	#Deleting the test model and the MFA folder
	$self->figmodel()->clearing_output($UniqueFilename);

	return $FinalReactionList;
}

=head3 GapFillingAlgorithm

Definition:
	FIGMODELmodel->GapFillingAlgorithm();

Description:
	This is a wrapper for running the gap filling algorithm on any model in the database.
	The algorithm performs a gap filling for any false negative prediction of the avialable experimental data.
	This function is threaded to improve efficiency: one thread does nothing but using the MFAToolkit to fill gaps for every false negative prediction.
	The other thread reads in the gap filling solutions, builds a test model for each solution, and runs the test model against all available experimental data.
	This function prints two important output files in the Model directory:
	1.) GapFillingOutput.txt: this is a summary of the results of the gap filling analysis
	2.) GapFillingErrorMatrix.txt: this lists the correct and incorrect predictions for each gapfilling solution implemented in a test model.
=cut

sub GapFillingAlgorithm {
	my ($self) = @_;

	#First the input model version and model filename should be simulated and the false negatives identified
	my ($FalsePostives,$FalseNegatives,$CorrectNegatives,$CorrectPositives,$Errorvector,$HeadingVector) = $self->RunAllStudiesWithDataFast("All");

	#Getting the filename
	my $UniqueFilename = $self->figmodel()->filename();

	#Printing the original performance vector
	$self->figmodel()->database()->print_array_to_file($self->directory().$self->id().$self->selected_version()."-OPEM".".txt",[$HeadingVector,$Errorvector]);

	my $PreviousGapFilling;
	if (-e $self->directory().$self->id().$self->selected_version()."-GFS.txt") {
		#Backing up the old solution file
		system("cp ".$self->directory().$self->id().$self->selected_version()."-GFS.txt ".$self->directory().$self->id().$self->selected_version()."-OldGFS.txt");
		unlink($self->directory().$self->id().$self->selected_version()."-GFS.txt");
	}
	if (-e $self->directory().$self->id().$self->selected_version()."-OldGFS.txt") {
		#Reading in the solution file from the previous gap filling if it exists
		$PreviousGapFilling = $self->figmodel()->database()->load_table($self->directory().$self->id().$self->selected_version()."-OldGFS.txt",";",",",0,["Experiment"]);
	}

	#Now we use the simulation output to make the gap filling run data
	my @Errors = split(/;/,$Errorvector);
	my @Headings = split(/;/,$HeadingVector);
	my $GapFillingRunSpecs = "";
	my $Count = 0;
	my $RescuedPreviousResults;
	my $RunCount = 0;
	my $SolutionExistedCount = 0;
	my $AcceptedSolutions = 0;
	my $RejectedSolutions = 0;
	my $NoExistingSolutions = 0;
	for (my $i=0; $i < @Errors; $i++) {
		if ($Errors[$i] == 3) {
			my @HeadingDataArray = split(/:/,$Headings[$i]);
			if ($HeadingDataArray[2] !~ m/^peg\./ || $HeadingDataArray[3] ne "none") {
				my $SolutionFound = 0;
				if (defined($PreviousGapFilling) && defined($PreviousGapFilling->get_row_by_key($HeadingDataArray[2],"Experiment"))) {
					my @Rows = $PreviousGapFilling->get_rows_by_key($HeadingDataArray[2],"Experiment");
					for (my $j=0; $j < @Rows; $j++) {
						if ($HeadingDataArray[2] =~ m/^peg\./) {
							my $ReactionList = $self->InspectSolution($HeadingDataArray[2],$HeadingDataArray[1],$Rows[$j]->{"Solution reactions"});
							if (defined($ReactionList)) {
								print join(",",@{$Rows[$j]->{"Solution reactions"}})."\t".join(",",@{$ReactionList})."\n";
								$SolutionFound++;
								push(@{$RescuedPreviousResults},$Rows[$j]->{"Experiment"}->[0].";".$Rows[$j]->{"Solution index"}->[0].";".$Rows[$j]->{"Solution cost"}->[0].";".join(",",@{$ReactionList}));
								$AcceptedSolutions++;
							} else {
								$RejectedSolutions++;
							}
						} else {
							my $ReactionList = $self->InspectSolution($HeadingDataArray[2],$HeadingDataArray[1],$Rows[$j]->{"Solution reactions"});
							if (defined($ReactionList)) {
								print join(",",@{$Rows[$j]->{"Solution reactions"}})."\t".join(",",@{$ReactionList})."\n";
								$SolutionFound++;
								push(@{$RescuedPreviousResults},$Rows[$j]->{"Experiment"}->[0].";".$Rows[$j]->{"Solution index"}->[0].";".$Rows[$j]->{"Solution cost"}->[0].";".join(",",@{$ReactionList}));
								$AcceptedSolutions++;
							} else {
								$RejectedSolutions++;
							}
						}
					}
				} else {
					$NoExistingSolutions++;
				}
				if ($SolutionFound == 0) {
					$RunCount++;
					if (length($GapFillingRunSpecs) > 0) {
						$GapFillingRunSpecs .= ";";
					}
					$GapFillingRunSpecs .= $HeadingDataArray[2].":".$HeadingDataArray[1].":".$HeadingDataArray[3];
				} else {
					$SolutionExistedCount++;
				}
			}
			$Count++;
		}
	}

	#Updating the growmatch progress table
	my $Row = $self->figmodel()->database()->get_row_by_key("GROWMATCH TABLE",$self->genome(),"ORGANISM",1);
	$Row->{"INITIAL FP"}->[0] = $FalsePostives;
	$Row->{"INITIAL FN"}->[0] = $FalseNegatives;
	$Row->{"GF TIMING"}->[0] = time()."-";
	$Row->{"FN WITH SOL"}->[0] = $FalseNegatives-$NoExistingSolutions;
	$Row->{"FN WITH ACCEPTED SOL"}->[0] = $SolutionExistedCount;
	$Row->{"TOTAL ACCEPTED GF SOL"}->[0] = $AcceptedSolutions;
	$Row->{"TOTAL REJECTED GF SOL"}->[0] = $RejectedSolutions;
	$Row->{"FN WITH NO SOL"}->[0] = $NoExistingSolutions+$RejectedSolutions;
	$self->figmodel()->database()->update_row("GROWMATCH TABLE",$Row,"ORGANISM");

	#Running the gap filling once to correct all false negative errors
	my $SolutionsFound = 0;
	my $GapFillingArray;
	push(@{$GapFillingArray},split(/;/,$GapFillingRunSpecs));
	my $GapFillingResults = $self->datagapfill($GapFillingArray,"GFS");
	if (defined($GapFillingResults)) {
		$SolutionsFound = 1;
	}

	if (defined($RescuedPreviousResults) && @{$RescuedPreviousResults} > 0) {
		#Printing previous solutions to GFS file
		$self->figmodel()->database()->print_array_to_file($self->directory().$self->id().$self->selected_version()."-GFS.txt",$RescuedPreviousResults,1);
		$SolutionsFound = 1;
	}

	#Recording the finishing of the gapfilling
	$Row = $self->figmodel()->database()->get_row_by_key("GROWMATCH TABLE",$self->genome(),"ORGANISM",1);
	$Row->{"GF TIMING"}->[0] .= time();
	$self->figmodel()->database()->update_row("GROWMATCH TABLE",$Row,"ORGANISM");

	if ($SolutionsFound == 1) {
		#Scheduling solution testing
		$self->figmodel()->add_job_to_queue({command => "testsolutions?".$self->id().$self->selected_version()."?-1?GF",user => $self->owner(),queue => "short"});
	} else {
		$self->figmodel()->error_message("No false negative predictions found. Data gap filling not necessary!");
	}

	return $self->figmodel()->success();
}

=head3 SolutionReconciliation
Definition:
	FIGMODELmodel->SolutionReconciliation();
Description:
	This is a wrapper for running the solution reconciliation algorithm on any model in the database.
	The algorithm performs a reconciliation of any gap filling solutions to identify the combination of solutions that results in the optimal model.
	This function prints out one output file in the Model directory: ReconciliationOutput.txt: this is a summary of the results of the reconciliation analysis
=cut

sub SolutionReconciliation {
	my ($self,$GapFill,$Stage) = @_;

	#Setting the output filenames
	my $OutputFilename;
	my $OutputFilenameTwo;
	if ($GapFill == 1) {
		$OutputFilename = $self->directory().$self->id().$self->selected_version()."-GFReconciliation.txt";
		$OutputFilenameTwo = $self->directory().$self->id().$self->selected_version()."-GFSRS.txt";
	} else {
		$OutputFilename = $self->directory().$self->id().$self->selected_version()."-GGReconciliation.txt";
		$OutputFilenameTwo = $self->directory().$self->id().$self->selected_version()."-GGSRS.txt";
	}

	#In stage one, we run the reconciliation and create a test file to check combined solution performance
	if (!defined($Stage) || $Stage == 1) {
		my $GrowMatchTable = $self->figmodel()->database()->LockDBTable("GROWMATCH TABLE");
		my $Row = $GrowMatchTable->get_row_by_key($self->genome(),"ORGANISM",1);
		$Row->{"GF RECONCILATION TIMING"}->[0] = time()."-";
		$GrowMatchTable->save();
		$self->figmodel()->database()->UnlockDBTable("GROWMATCH TABLE");

		#Getting a unique filename
		my $UniqueFilename = $self->figmodel()->filename();

		#Copying over the necessary files
		if ($GapFill == 1) {
			if (!-e $self->directory().$self->id().$self->selected_version()."-GFEM.txt") {
				print STDERR "FIGMODEL:SolutionReconciliation:".$self->directory().$self->id().$self->selected_version()."-GFEM.txt file not found. Could not reconcile!";
				return 0;
			}
			if (!-e $self->directory().$self->id().$self->selected_version()."-OPEM.txt") {
				print STDERR "FIGMODEL:SolutionReconciliation:".$self->directory().$self->id().$self->selected_version()."-OPEM.txt file not found. Could not reconcile!";
				return 0;
			}
			system("cp ".$self->directory().$self->id().$self->selected_version()."-GFEM.txt ".$self->figmodel()->config("MFAToolkit input files")->[0].$UniqueFilename."-GFEM.txt");
			system("cp ".$self->directory().$self->id().$self->selected_version()."-OPEM.txt ".$self->figmodel()->config("MFAToolkit input files")->[0].$UniqueFilename."-OPEM.txt");
			#Backing up and deleting the existing reconciliation file
			if (-e $OutputFilename) {
				system("cp ".$OutputFilename." ".$self->directory().$self->id().$self->selected_version()."-OldGFReconciliation.txt");
				unlink($OutputFilename);
			}
		} else {
			if (!-e $self->directory().$self->id().$self->selected_version()."-GGEM.txt") {
				print STDERR "FIGMODEL:SolutionReconciliation:".$self->directory().$self->id().$self->selected_version()."-GGEM.txt file not found. Could not reconcile!";
				return 0;
			}
			if (!-e $self->directory().$self->id().$self->selected_version()."-GGOPEM.txt") {
				print STDERR "FIGMODEL:SolutionReconciliation:".$self->directory().$self->id().$self->selected_version()."-GGOPEM.txt file not found. Could not reconcile!";
				return 0;
			}
			system("cp ".$self->directory().$self->id().$self->selected_version()."-GGEM.txt ".$self->figmodel()->config("MFAToolkit input files")->[0].$UniqueFilename."-GGEM.txt");
			system("cp ".$self->directory().$self->id().$self->selected_version()."-GGOPEM.txt ".$self->figmodel()->config("MFAToolkit input files")->[0].$UniqueFilename."-OPEM.txt");
			#Backing up and deleting the existing reconciliation file
			if (-e $OutputFilename) {
				system("cp ".$OutputFilename." ".$self->directory().$self->id().$self->selected_version()."-OldGGReconciliation.txt");
				unlink($OutputFilename);
			}
		}

		#Running the reconciliation
		system($self->figmodel()->GenerateMFAToolkitCommandLineCall($UniqueFilename,$self->id(),"NONE",["SolutionReconciliation"],{"Solution data for model optimization" => $UniqueFilename},"Reconciliation".$UniqueFilename.".log",undef,$self->selected_version()));
		$GrowMatchTable = $self->figmodel()->database()->LockDBTable("GROWMATCH TABLE");
		$Row = $GrowMatchTable->get_row_by_key($self->genome(),"ORGANISM",1);
		$Row->{"GF RECONCILATION TIMING"}->[0] .= time();
		$GrowMatchTable->save();
		$self->figmodel()->database()->UnlockDBTable("GROWMATCH TABLE");

		#Loading the problem report from the reconciliation run
		my $ReconciliatonOutput = $self->figmodel()->LoadProblemReport($UniqueFilename);
		print $UniqueFilename."\n";
		#Clearing output files
		$self->figmodel()->clearing_output($UniqueFilename,"Reconciliation".$UniqueFilename.".log");
		$ReconciliatonOutput->save("/home/chenry/Test.txt");

		#Checking the a problem report was found and was loaded
		if (!defined($ReconciliatonOutput) || $ReconciliatonOutput->size() < 1 || !defined($ReconciliatonOutput->get_row(0)->{"Notes"}->[0])) {
			print STDERR "FIGMODEL:SolutionReconciliation: MFAToolkit output from SolutionReconciliation of ".$self->id()." not found!\n\n";
			return 0;
		}

		#Processing the solutions
		my $SolutionCount = 0;
		my $ReactionSetHash;
		my $SingleReactionHash;
		my $ReactionDataHash;
		for (my $n=0; $n < $ReconciliatonOutput->size(); $n++) {
			if (defined($ReconciliatonOutput->get_row($n)->{"Notes"}->[0]) && $ReconciliatonOutput->get_row($n)->{"Notes"}->[0] =~ m/^Recursive\sMILP\s([^;]+)/) {
				#Breaking up the solution into reaction sets
				my @ReactionSets = split(/\|/,$1);
				#Creating reaction lists for each set
				my $SolutionHash;
				for (my $i=0; $i < @ReactionSets; $i++) {
					if (length($ReactionSets[$i]) > 0) {
						my @Alternatives = split(/:/,$ReactionSets[$i]);
						for (my $j=1; $j < @Alternatives; $j++) {
							if (length($Alternatives[$j]) > 0) {
								push(@{$SolutionHash->{$Alternatives[$j]}},$Alternatives[0]);
							}
						}
						if (@Alternatives == 1) {
							$SingleReactionHash->{$Alternatives[0]}->{$SolutionCount} = 1;
							if (!defined($SingleReactionHash->{$Alternatives[0]}->{"COUNT"})) {
								$SingleReactionHash->{$Alternatives[0]}->{"COUNT"} = 0;
							}
							$SingleReactionHash->{$Alternatives[0]}->{"COUNT"}++;
						}
					}
				}
				#Identifying reactions sets and storing the sets in the reactions set hash
				foreach my $Solution (keys(%{$SolutionHash})) {
					my $SetKey = join(",",sort(@{$SolutionHash->{$Solution}}));
					if (!defined($ReactionSetHash->{$SetKey}->{$SetKey}->{$SolutionCount})) {
						$ReactionSetHash->{$SetKey}->{$SetKey}->{$SolutionCount} = 1;
						if (!defined($ReactionSetHash->{$SetKey}->{$SetKey}->{"COUNT"})) {
							$ReactionSetHash->{$SetKey}->{$SetKey}->{"COUNT"} = 0;
						}
						$ReactionSetHash->{$SetKey}->{$SetKey}->{"COUNT"}++;
					}
					$ReactionSetHash->{$SetKey}->{$Solution}->{$SolutionCount} = 1;
					if (!defined($ReactionSetHash->{$SetKey}->{$Solution}->{"COUNT"})) {
						$ReactionSetHash->{$SetKey}->{$Solution}->{"COUNT"} = 0;
					}
					$ReactionSetHash->{$SetKey}->{$Solution}->{"COUNT"}++;
				}
				$SolutionCount++;
			}
		}

		#Handling the scenario where no solutions were found
		if ($SolutionCount == 0) {
			print STDERR "FIGMODEL:SolutionReconciliation: Reconciliation unsuccessful. No solution found.\n\n";
			return 0;
		}

		#Printing results without solution performance figures. Also printing solution test file
		open (RECONCILIATION, ">$OutputFilename");
		#Printing the file heading
		print RECONCILIATION "DATABASE;DEFINITION;REVERSIBLITY;DELTAG;DIRECTION;NUMBER OF SOLUTIONS";
		for (my $i=0; $i < $SolutionCount; $i++) {
			print RECONCILIATION ";Solution ".$i;
		}
		print RECONCILIATION "\n";
		#Printing the singlet reactions first
		my $Solutions;
		print RECONCILIATION "SINGLET REACTIONS\n";
 		my @SingletReactions = keys(%{$SingleReactionHash});
		for (my $j=0; $j < $SolutionCount; $j++) {
			$Solutions->[$j]->{"BASE"} = $j;
		}
		for (my $i=0; $i < @SingletReactions; $i++) {
			my $ReactionData;
			if (defined($ReactionDataHash->{$SingletReactions[$i]})) {
				$ReactionData = $ReactionDataHash->{$SingletReactions[$i]};
			} else {
				my $Direction = substr($SingletReactions[$i],0,1);
				if ($Direction eq "+") {
					$Direction = "=>";
				} else {
					$Direction = "<=";
				}
				my $Reaction = substr($SingletReactions[$i],1);
				$ReactionData = FIGMODELObject->load($self->figmodel()->config("reaction directory")->[0].$Reaction,"\t");
				$ReactionData->{"DIRECTIONS"}->[0] = $Direction;
				$ReactionData->{"REACTIONS"}->[0] = $Reaction;
				if (!defined($ReactionData->{"DEFINITION"}->[0])) {
					$ReactionData->{"DEFINITION"}->[0] = "UNKNOWN";
				}
				if (!defined($ReactionData->{"THERMODYNAMIC REVERSIBILITY"}->[0])) {
					$ReactionData->{"THERMODYNAMIC REVERSIBILITY"}->[0] = "UNKNOWN";
				}
				if (!defined($ReactionData->{"DELTAG"}->[0])) {
					$ReactionData->{"DELTAG"}->[0] = "UNKNOWN";
				}
				$ReactionDataHash->{$SingletReactions[$i]} = $ReactionData;
			}
			print RECONCILIATION $ReactionData->{"REACTIONS"}->[0].";".$ReactionData->{"DEFINITION"}->[0].";".$ReactionData->{"THERMODYNAMIC REVERSIBILITY"}->[0].";".$ReactionData->{"DELTAG"}->[0].";".$ReactionData->{"DIRECTIONS"}->[0].";".$SingleReactionHash->{$SingletReactions[$i]}->{"COUNT"};
			for (my $j=0; $j < $SolutionCount; $j++) {
				print RECONCILIATION ";";
				if (defined($SingleReactionHash->{$SingletReactions[$i]}->{$j})) {
					$Solutions->[$j]->{$SingletReactions[$i]} = 1;
					$Solutions->[$j]->{"BASE"} = $j;
					print RECONCILIATION "|".$j."|";
				}
			}
			print RECONCILIATION "\n";
		}
		#Printing the reaction sets with alternatives
		print RECONCILIATION "Reaction sets with alternatives\n";
		my @ReactionSets = keys(%{$ReactionSetHash});
		foreach my $ReactionSet (@ReactionSets) {
			my $NewSolutions;
			my $BaseReactions;
			my $AltList = [$ReactionSet];
			push(@{$AltList},keys(%{$ReactionSetHash->{$ReactionSet}}));
			for (my $j=0; $j < @{$AltList}; $j++) {
				my $CurrentNewSolutions;
				my $Index;
				if ($j == 0) {
					print RECONCILIATION "NEW SET\n";
				} elsif ($AltList->[$j] ne $ReactionSet) {
					print RECONCILIATION "ALTERNATIVE SET\n";
					#For each base solution in which this set is represented, we copy the base solution to the new solution
					my $NewSolutionCount = 0;
					for (my $k=0; $k < $SolutionCount; $k++) {
						if (defined($ReactionSetHash->{$ReactionSet}->{$AltList->[$j]}->{$k})) {
							if (defined($Solutions)) {
								$Index->{$k} = @{$Solutions} + $NewSolutionCount;
							} else {
								$Index->{$k} = $NewSolutionCount;
							}
							if (defined($NewSolutions) && @{$NewSolutions} > 0) {
								$Index->{$k} += @{$NewSolutions};
							}
							$CurrentNewSolutions->[$NewSolutionCount] = {};
							foreach my $Reaction (keys(%{$Solutions->[$k]})) {
								$CurrentNewSolutions->[$NewSolutionCount]->{$Reaction} = $Solutions->[$k]->{$Reaction};
							}
							$NewSolutionCount++;
						}
					}
				}
				if ($j == 0 || $AltList->[$j] ne $ReactionSet) {
					my @SingletReactions = split(/,/,$AltList->[$j]);
					for (my $i=0; $i < @SingletReactions; $i++) {
						#Adding base reactions to base solutions and set reactions the new solutions
						if ($j == 0) {
							push(@{$BaseReactions},$SingletReactions[$i]);
						} else {
							for (my $k=0; $k < @{$CurrentNewSolutions}; $k++) {
								$CurrentNewSolutions->[$k]->{$SingletReactions[$i]} = 1;
							}
						}
						#Getting reaction data and printing reaction in output file
						my $ReactionData;
						if (defined($ReactionDataHash->{$SingletReactions[$i]})) {
							$ReactionData = $ReactionDataHash->{$SingletReactions[$i]};
						} else {
							my $Direction = substr($SingletReactions[$i],0,1);
							if ($Direction eq "+") {
								$Direction = "=>";
							} else {
								$Direction = "<=";
							}
							my $Reaction = substr($SingletReactions[$i],1);
							$ReactionData = FIGMODELObject->load($self->figmodel()->config("reaction directory")->[0].$Reaction,"\t");
							$ReactionData->{"DIRECTIONS"}->[0] = $Direction;
							$ReactionData->{"REACTIONS"}->[0] = $Reaction;
							if (!defined($ReactionData->{"DEFINITION"}->[0])) {
								$ReactionData->{"DEFINITION"}->[0] = "UNKNOWN";
							}
							if (!defined($ReactionData->{"THERMODYNAMIC REVERSIBILITY"}->[0])) {
								$ReactionData->{"THERMODYNAMIC REVERSIBILITY"}->[0] = "UNKNOWN";
							}
							if (!defined($ReactionData->{"DELTAG"}->[0])) {
								$ReactionData->{"DELTAG"}->[0] = "UNKNOWN";
							}
							$ReactionDataHash->{$SingletReactions[$i]} = $ReactionData;
						}
						print RECONCILIATION $ReactionData->{"REACTIONS"}->[0].";".$ReactionData->{"DEFINITION"}->[0].";".$ReactionData->{"THERMODYNAMIC REVERSIBILITY"}->[0].";".$ReactionData->{"DELTAG"}->[0].";".$ReactionData->{"DIRECTIONS"}->[0].";".$ReactionSetHash->{$ReactionSet}->{$AltList->[$j]}->{"COUNT"};
						for (my $k=0; $k < $SolutionCount; $k++) {
							print RECONCILIATION ";";
							if (defined($ReactionSetHash->{$ReactionSet}->{$AltList->[$j]}->{$k})) {
								if ($j == 0) {
									print RECONCILIATION "|".$k."|";
								} else {
									print RECONCILIATION "|".$Index->{$k}."|";
								}
							}
						}
						print RECONCILIATION "\n";
					}
					#Adding the current new solutions to the new solutions array
					if (defined($CurrentNewSolutions) && @{$CurrentNewSolutions} > 0) {
						push(@{$NewSolutions},@{$CurrentNewSolutions});
					}
				}
			}
			#Adding the base reactions to all existing solutions
			for (my $j=0; $j < @{$Solutions}; $j++) {
				if (defined($ReactionSetHash->{$ReactionSet}->{$ReactionSet}->{$Solutions->[$j]->{"BASE"}})) {
					foreach my $SingleReaction (@{$BaseReactions}) {
						$Solutions->[$j]->{$SingleReaction} = 1;
					}
				}
			}
			#Adding the new solutions to the set of existing solutions
			push(@{$Solutions},@{$NewSolutions});
		}
		close(RECONCILIATION);
		#Now printing a file that defines all of the solutions in a format the testsolutions function understands
		open (RECONCILIATION, ">$OutputFilenameTwo");
		print RECONCILIATION "Experiment;Solution index;Solution cost;Solution reactions\n";
		for (my $i=0; $i < @{$Solutions}; $i++) {
			delete($Solutions->[$i]->{"BASE"});
			print RECONCILIATION "SR".$i.";".$i.";10;".join(",",keys(%{$Solutions->[$i]}))."\n";
		}
		close(RECONCILIATION);

		$GrowMatchTable = $self->figmodel()->database()->LockDBTable("GROWMATCH TABLE");
		$Row = $GrowMatchTable->get_row_by_key($self->genome(),"ORGANISM",1);
		$Row->{"GF RECON TESTING TIMING"}->[0] = time()."-";
		$Row->{"GF RECON SOLUTIONS"}->[0] = @{$Solutions};
		$GrowMatchTable->save();
		$self->figmodel()->database()->UnlockDBTable("GROWMATCH TABLE");

		#Scheduling the solution testing
		if ($GapFill == 1) {
			system($self->figmodel()->config("scheduler executable")->[0]." \"add:testsolutions?".$self->id().$self->selected_version()."?-1?GFSR:BACK:fast:QSUB\"");
		} else {
			system($self->figmodel()->config("scheduler executable")->[0]." \"add:testsolutions?".$self->id().$self->selected_version()."?-1?GGSR:BACK:fast:QSUB\"");
		}
	} else {
		#Reading in the solution testing results
		my $Data;
		if ($GapFill == 1) {
			$Data = $self->figmodel()->database()->load_single_column_file($self->directory().$self->id().$self->selected_version()."-GFSREM.txt","");
		} else {
			$Data = $self->figmodel()->database()->load_single_column_file($self->directory().$self->id().$self->selected_version()."-GGSREM.txt","");
		}

		#Reading in the preliminate reconciliation report
		my $OutputData = $self->figmodel()->database()->load_single_column_file($OutputFilename,"");
		#Replacing the file tags with actual performance data
		my $Count = 0;
		for (my $i=0; $i < @{$Data}; $i++) {
			if ($Data->[$i] =~ m/^SR(\d+);.+;(\d+\/\d+);/) {
				my $Index = $1;
				my $Performance = $Index."/".$2;
				for (my $j=0; $j < @{$OutputData}; $j++) {
					$OutputData->[$j] =~ s/\|$Index\|/$Performance/g;
				}
			}
		}
		$self->figmodel()->database()->print_array_to_file($OutputFilename,$OutputData);

		my $GrowMatchTable = $self->figmodel()->database()->LockDBTable("GROWMATCH TABLE");
		my $Row = $GrowMatchTable->get_row_by_key($self->genome(),"ORGANISM",1);
		$Row->{"GF RECON TESTING TIMING"}->[0] .= time();
		$GrowMatchTable->save();
		$self->figmodel()->database()->UnlockDBTable("GROWMATCH TABLE");
	}

	return 1;
}

=head3 DetermineCofactorLipidCellWallComponents
Definition:
	{cofactor=>{string:compound id=>float:coefficient},lipid=>...cellWall=>} = FIGMODELmodel->DetermineCofactorLipidCellWallComponents();
Description:
=cut
sub DetermineCofactorLipidCellWallComponents {
	my ($self) = @_;
	my $templateResults;
	my $genomestats = $self->genomeObj()->genome_stats();
	my $Class = $self->ppo()->cellwalltype();
	my $Name = $self->name();
	my $translation = {COFACTOR=>"cofactor",LIPIDS=>"lipid","CELL WALL"=>"cellWall"};
	#Checking for phoenix variants
	my $PhoenixVariantTable = $self->figmodel()->database()->get_table("Phoenix variants table");
	my $Phoenix = 0;
	my @Rows = $PhoenixVariantTable->get_rows_by_key($self->genome(),"GENOME");
	my $VariantHash;
	for (my $i=0; $i < @Rows; $i++) {
		$Phoenix = 1;
		if (defined($Rows[$i]->{"SUBSYSTEM"}) && defined($Rows[$i]->{"VARIANT"})) {
			$VariantHash->{$Rows[$i]->{"SUBSYSTEM"}->[0]} = $Rows[$i]->{"VARIANT"}->[0];
		}
	}
	#Collecting genome data
	my $RoleHash;
	my $FeatureTable = $self->figmodel()->GetGenomeFeatureTable($self->genome());
	for (my $i=0; $i < $FeatureTable->size(); $i++) {
		if (defined($FeatureTable->get_row($i)->{"ROLES"})) {
			for (my $j=0; $j < @{$FeatureTable->get_row($i)->{"ROLES"}}; $j++) {
				$RoleHash->{$FeatureTable->get_row($i)->{"ROLES"}->[$j]} = 1;
			}
		}
	}
	my $ssHash = $self->genomeObj()->active_subsystems();
	my @ssList = keys(%{$ssHash});
	for (my $i=0; $i < @ssList; $i++) {
		if (!defined($VariantHash->{$ssList[$i]})) {
			$VariantHash->{$ssList[$i]} = 1;
		}
	}
	#Scanning through the template item by item and determinine which biomass components should be added
	my $includedHash;
	my $BiomassReactionTemplateTable = $self->figmodel()->database()->get_table("BIOMASSTEMPLATE");
	for (my $i=0; $i < $BiomassReactionTemplateTable->size(); $i++) {
		my $Row = $BiomassReactionTemplateTable->get_row($i); 
		if (defined($translation->{$Row->{CLASS}->[0]})) {
			my $coef = -1;
			if ($Row->{"REACTANT"}->[0] eq "NO") {
				$coef = 1;
				if ($Row->{"COEFFICIENT"}->[0] =~ m/cpd/) {
					$coef = $Row->{"COEFFICIENT"}->[0];
				}
			}
			if (defined($Row->{"INCLUSION CRITERIA"}->[0]) && $Row->{"INCLUSION CRITERIA"}->[0] eq "UNIVERSAL") {
				$includedHash->{$Row->{"ID"}->[0]} = 1;
				$templateResults->{$translation->{$Row->{CLASS}->[0]}}->{$Row->{"ID"}->[0]} = $coef;
			} elsif (defined($Row->{"INCLUSION CRITERIA"}->[0])) {
				my $Criteria = $Row->{"INCLUSION CRITERIA"}->[0];
				my $End = 0;
				while ($End == 0) {
					if ($Criteria =~ m/^(.+)(AND)\{([^{^}]+)\}(.+)$/ || $Criteria =~ m/^(AND)\{([^{^}]+)\}$/ || $Criteria =~ m/^(.+)(OR)\{([^{^}]+)\}(.+)$/ || $Criteria =~ m/^(OR)\{([^{^}]+)\}$/) {
						print $Criteria." : ";
						my $Start = "";
						my $End = "";
						my $Condition = $1;
						my $Data = $2;
						if ($1 ne "AND" && $1 ne "OR") {
							$Start = $1;
							$End = $4;
							$Condition = $2;
							$Data = $3;
						}
						my $Result = "YES";
						if ($Condition eq "OR") {
							$Result = "NO";
						}
						my @Array = split(/\|/,$Data);
						for (my $j=0; $j < @Array; $j++) {
							if ($Array[$j] eq "YES" && $Condition eq "OR") {
								$Result = "YES";
								last;
							} elsif ($Array[$j] eq "NO" && $Condition eq "AND") {
								$Result = "NO";
								last;
							} elsif ($Array[$j] =~ m/^COMPOUND:(.+)/) {
								if (defined($includedHash->{$1}) && $Condition eq "OR") {
									$Result = "YES";
									last;
								} elsif (!defined($includedHash->{$1}) && $Condition eq "AND") {							
									$Result = "NO";
									last;
								}
							} elsif ($Array[$j] =~ m/^!COMPOUND:(.+)/) {
								if (!defined($includedHash->{$1}) && $Condition eq "OR") {
									$Result = "YES";
									last;
								} elsif (defined($includedHash->{$1}) && $Condition eq "AND") {							
									$Result = "NO";
									last;
								}
							} elsif ($Array[$j] =~ m/^NAME:(.+)/) {
								my $Comparison = $1;
								if ((!defined($Comparison) || !defined($Name) || $Name =~ m/$Comparison/) && $Condition eq "OR") {
									$Result = "YES";
									last;
								} elsif (defined($Comparison) && defined($Name) && $Name !~ m/$Comparison/ && $Condition eq "AND") {
									$Result = "NO";
									last;
								}
							} elsif ($Array[$j] =~ m/^!NAME:(.+)/) {
								my $Comparison = $1;
								if ((!defined($Comparison) || !defined($Name) || $Name !~ m/$Comparison/) && $Condition eq "OR") {
									$Result = "YES";
									last;
								} elsif (defined($Comparison) && defined($Name) && $Name =~ m/$Comparison/ && $Condition eq "AND") {
									$Result = "NO";
									last;
								}
							} elsif ($Array[$j] =~ m/^SUBSYSTEM:(.+)/) {
								my @SubsystemArray = split(/`/,$1);
								if (@SubsystemArray == 1) {
									if (defined($VariantHash->{$SubsystemArray[0]}) && $VariantHash->{$SubsystemArray[0]} ne -1 && $Condition eq "OR") {
										$Result = "YES";
										last;
									} elsif ((!defined($VariantHash->{$SubsystemArray[0]}) || $VariantHash->{$SubsystemArray[0]} eq -1) && $Condition eq "AND") {
										$Result = "NO";
										last;
									}
								} else {
									my $Match = 0;
									for (my $k=1; $k < @SubsystemArray; $k++) {
										if (defined($VariantHash->{$SubsystemArray[0]}) && $VariantHash->{$SubsystemArray[0]} eq $SubsystemArray[$k]) {
											$Match = 1;
											last;
										}
									}
									if ($Match == 1 && $Condition eq "OR") {
										$Result = "YES";
										last;
									} elsif ($Match != 1 && $Condition eq "AND") {
										$Result = "NO";
										last;
									}
								}
							} elsif ($Array[$j] =~ m/^!SUBSYSTEM:(.+)/) {
								my @SubsystemArray = split(/`/,$1);
								if (@SubsystemArray == 1) {
									if ((!defined($VariantHash->{$SubsystemArray[0]}) || $VariantHash->{$SubsystemArray[0]} eq -1) && $Condition eq "OR") {
										$Result = "YES";
										last;
									} elsif (defined($VariantHash->{$SubsystemArray[0]}) && $VariantHash->{$SubsystemArray[0]} ne -1 && $Condition eq "AND") {
										$Result = "NO";
										last;
									}
								} else {
									my $Match = 0;
									for (my $k=1; $k < @SubsystemArray; $k++) {
										if (defined($VariantHash->{$SubsystemArray[0]}) && $VariantHash->{$SubsystemArray[0]} eq $SubsystemArray[$k]) {
											$Match = 1;
											last;
										}
									}
									if ($Match != 1 && $Condition eq "OR") {
										$Result = "YES";
										last;
									} elsif ($Match == 1 && $Condition eq "AND") {
										$Result = "NO";
										last;
									}
								}
							} elsif ($Array[$j] =~ m/^ROLE:(.+)/) {
								if (defined($RoleHash->{$1}) && $Condition eq "OR") {
									$Result = "YES";
									last;
								} elsif (!defined($RoleHash->{$1}) && $Condition eq "AND") {
									$Result = "NO";
									last;
								}
							} elsif ($Array[$j] =~ m/^!ROLE:(.+)/) {
								if (!defined($RoleHash->{$1}) && $Condition eq "OR") {
									$Result = "YES";
									last;
								} elsif (defined($RoleHash->{$1}) && $Condition eq "AND") {
									$Result = "NO";
									last;
								}
							} elsif ($Array[$j] =~ m/^CLASS:(.+)/) {
								if ($Class eq $1 && $Condition eq "OR") {
									$Result = "YES";
									last;
								} elsif ($Class ne $1 && $Condition eq "AND") {
									$Result = "NO";
									last;
								}
							} elsif ($Array[$j] =~ m/^!CLASS:(.+)/) {
								if ($Class ne $1 && $Condition eq "OR") {
									$Result = "YES";
									last;
								} elsif ($Class eq $1 && $Condition eq "AND") {
									$Result = "NO";
									last;
								}
							}
						}
						$Criteria = $Start.$Result.$End;
						print $Criteria."\n";
					} else {
						$End = 1;
						last;
					}
				}
				if ($Criteria eq "YES") {
					$templateResults->{$translation->{$Row->{CLASS}->[0]}}->{$Row->{"ID"}->[0]} = $coef;
					$includedHash->{$Row->{"ID"}->[0]} = 1;
				}
			}
		}
	}
	my $types = ["cofactor","lipid","cellWall"];
	my $cpdMgr = $self->figmodel()->database()->get_object_manager("compound");
	for (my $i=0; $i < @{$types}; $i++) {
		my @list =	keys(%{$templateResults->{$types->[$i]}});
		my $entries = 0;
		for (my $j=0; $j < @list; $j++) {
			if ($templateResults->{$types->[$i]}->{$list[$j]} eq "-1") {
				my $objs = $cpdMgr->get_objects({id=>$list[$j]});
				if (!defined($objs->[0]) || $objs->[0]->mass() == 0) {
					$templateResults->{$types->[$i]}->{$list[$j]} = -1e-5;
				} else {
					$entries++;
				}
			}
		}
		for (my $j=0; $j < @list; $j++) {
			if ($templateResults->{$types->[$i]}->{$list[$j]} eq "-1") {
				$templateResults->{$types->[$i]}->{$list[$j]} = -1/$entries;
			} elsif ($templateResults->{$types->[$i]}->{$list[$j]} =~ m/cpd/) {
				my $netCoef = 0;
				my @allcpd = split(/,/,$templateResults->{$types->[$i]}->{$list[$j]});
				for (my $k=0; $k < @allcpd; $k++) {
					if (defined($templateResults->{$types->[$i]}->{$allcpd[$k]}) && $templateResults->{$types->[$i]}->{$allcpd[$k]} ne "-1e-5") {
						$netCoef += (1/$entries);
					} elsif (defined($templateResults->{$types->[$i]}->{$allcpd[$k]}) && $templateResults->{$types->[$i]}->{$allcpd[$k]} eq "-1e-5") {
						$netCoef += 1e-5;
					}
				}
				$templateResults->{$types->[$i]}->{$list[$j]} = $netCoef;
			}
		}
	}
	return $templateResults;
}

=head3 BuildSpecificBiomassReaction
Definition:
	FIGMODELmodel->BuildSpecificBiomassReaction();
Description:
=cut
sub BuildSpecificBiomassReaction {
	my ($self) = @_;
	#Checking if the current biomass reaction appears in more than on model, if not, this biomass reaction is conserved for this model
	my $biomassID = $self->biomassReaction();
	if ($biomassID =~ m/bio\d\d\d\d\d/) {
		my $mdlObs = $self->figmodel()->database()->get_objects("model",{
			biomassReaction=>$biomassID
		});
		if (defined($mdlObs->[1])) {
			$biomassID = "NONE";
		}
	}
	#If the biomass ID is "NONE", then we create a new biomass reaction for the model
	my $bioObj;
	my $originalPackages = "";
	my $originalEssReactions = "";
	if ($biomassID !~ m/bio\d\d\d\d\d/) {
		#Getting the current largest ID
		$biomassID = $self->figmodel()->database()->check_out_new_id("bof");
		$bioObj = $self->figmodel()->database()->create_object("bof",{
			id=>$biomassID,owner=>$self->owner(),name=>"Biomass",equation=>"NONE",protein=>"0",
			energy=>"0",DNA=>"0",RNA=>"0",lipid=>"0",cellWall=>"0",cofactor=>"0",
			modificationDate=>time(),creationDate=>time(),
			cofactorPackage=>"NONE",lipidPackage=>"NONE",cellWallPackage=>"NONE",
			DNACoef=>"NONE",RNACoef=>"NONE",proteinCoef=>"NONE",lipidCoef=>"NONE",
			cellWallCoef=>"NONE",cofactorCoef=>"NONE",essentialRxn=>"NONE"
		});
		if (!defined($bioObj)) {
			die $self->error_message("BuildSpecificBiomassReaction():Could not create new biomass reaction ".$biomassID."!");
		}
	} else {
		#Getting the biomass DB handler from the database
		my $objs = $self->figmodel()->database()->get_objects("bof",{id=>$biomassID});
		if (!defined($objs->[0])) {
			die $self->error_message("BuildSpecificBiomassReaction():Could not find biomass reaction ".$biomassID." in database!");
		}
		$bioObj = $objs->[0];
		$bioObj->owner($self->owner());
		if (defined($bioObj->essentialRxn())) {
			$originalEssReactions = $bioObj->essentialRxn();
			$originalPackages = $bioObj->cofactorPackage().$bioObj->lipidPackage().$bioObj->cellWallPackage();
		}
	}
	#Getting genome stats
	my $genomestats = $self->genomeObj()->genome_stats();
	my $Class = $self->ppo()->cellwalltype();
	#Setting global coefficients based on cell wall type
	my $biomassCompounds;
	my $compounds;
	if ($Class eq "Gram positive") {
		$compounds->{RNA} = {cpd00002=>-0.262,cpd00012=>1,cpd00038=>-0.323,cpd00052=>-0.199,cpd00062=>-0.215};
		$compounds->{protein} = {cpd00001=>1,cpd00023=>-0.0637,cpd00033=>-0.0999,cpd00035=>-0.0653,cpd00039=>-0.0790,cpd00041=>-0.0362,cpd00051=>-0.0472,cpd00053=>-0.0637,cpd00054=>-0.0529,cpd00060=>-0.0277,cpd00065=>-0.0133,cpd00066=>-0.0430,cpd00069=>-0.0271,cpd00084=>-0.0139,cpd00107=>-0.0848,cpd00119=>-0.0200,cpd00129=>-0.0393,cpd00132=>-0.0362,cpd00156=>-0.0751,cpd00161=>-0.0456,cpd00322=>-0.0660};
		$bioObj->protein("0.5284");
		$bioObj->DNA("0.026");
		$bioObj->RNA("0.0655");
		$bioObj->lipid("0.075");
		$bioObj->cellWall("0.25");
		$bioObj->cofactor("0.10");
	} else {
		$compounds->{RNA} = {cpd00002=>-0.262,cpd00012=>1,cpd00038=>-0.322,cpd00052=>-0.2,cpd00062=>-0.216};
		$compounds->{protein} = {cpd00001=>1,cpd00023=>-0.0492,cpd00033=>-0.1145,cpd00035=>-0.0961,cpd00039=>-0.0641,cpd00041=>-0.0451,cpd00051=>-0.0554,cpd00053=>-0.0492,cpd00054=>-0.0403,cpd00060=>-0.0287,cpd00065=>-0.0106,cpd00066=>-0.0347,cpd00069=>-0.0258,cpd00084=>-0.0171,cpd00107=>-0.0843,cpd00119=>-0.0178,cpd00129=>-0.0414,cpd00132=>-0.0451,cpd00156=>-0.0791,cpd00161=>-0.0474,cpd00322=>-0.0543};
		$bioObj->protein("0.563");
		$bioObj->DNA("0.031");
		$bioObj->RNA("0.21");
		$bioObj->lipid("0.093");
		$bioObj->cellWall("0.177");
		$bioObj->cofactor("0.039");
	}
	#Setting energy coefficient for all reactions
	$bioObj->energy("40");
	$compounds->{energy} = {cpd00002=>-1,cpd00001=>-1,cpd00008=>1,cpd00009=>1,cpd00067=>1};
	#Setting DNA coefficients based on GC content
	my $gc = $self->figmodel()->get_genome_gc_content($self->genome());
	$compounds->{DNA} = {cpd00012=>1,cpd00115=>0.5*(1-$gc),cpd00241=>0.5*$gc,cpd00356=>0.5*$gc,cpd00357=>0.5*(1-$gc)};
	#Setting Lipid,cell wall,and cofactor coefficients based on biomass template
	my $templateResults = $self->DetermineCofactorLipidCellWallComponents();
	$compounds->{cofactor} = $templateResults->{cofactor};
	$compounds->{lipid} = $templateResults->{lipid};
	$compounds->{cellWall} = $templateResults->{cellWall};
	#Getting package number for cofactor, lipid, and cell wall
	my $packages;
	my $packageTypes = ["Cofactor","Lipid","CellWall"];
	my $translation = {"Cofactor"=>"cofactor","Lipid"=>"lipid","CellWall"=>"cellWall"};
	for (my $i=0; $i < @{$packageTypes}; $i++) {
		my @cpdList = keys(%{$compounds->{$translation->{$packageTypes->[$i]}}});
		my $function = $translation->{$packageTypes->[$i]}."Package";
		if (@cpdList == 0) {
			$bioObj->$function("NONE");
		} else {
			my $cpdgrpObs = $self->figmodel()->database()->get_objects("cpdgrp",{type=>$packageTypes->[$i]."Package"});
			for (my $j=0; $j < @{$cpdgrpObs}; $j++) {
				$packages->{$packageTypes->[$i]}->{$cpdgrpObs->[$j]->grouping()}->{$cpdgrpObs->[$j]->COMPOUND()} = 1;
			}
			my @packageList = keys(%{$packages->{$packageTypes->[$i]}});
			my $packageHash;
			for (my $j=0; $j < @packageList; $j++) {
				$packageHash->{join("|",sort(keys(%{$packages->{$packageTypes->[$i]}->{$packageList[$j]}})))} = $packageList[$j];
			}
			if (defined($packageHash->{join("|",sort(keys(%{$compounds->{$translation->{$packageTypes->[$i]}}})))})) {
				$bioObj->$function($packageHash->{join("|",sort(keys(%{$compounds->{$translation->{$packageTypes->[$i]}}})))});
			} else {
				my $newPackageID = $self->figmodel()->database()->check_out_new_id($packageTypes->[$i]."Package");
				$bioObj->$function($newPackageID);
				my @cpdList = keys(%{$compounds->{$translation->{$packageTypes->[$i]}}});
				for (my $j=0; $j < @cpdList; $j++) {
					$self->figmodel()->database()->create_object("cpdgrp",{
						COMPOUND=>$cpdList[$j],
						grouping=>$newPackageID,
						type=>$packageTypes->[$i]."Package"
					});	
				}
			}
		}
	}
	#Filling in coefficient terms in database and calculating global reaction coefficients based on classification abundancies
	my $equationCompounds;
	my $types = ["RNA","DNA","protein","lipid","cellWall","cofactor","energy"];
	for (my $i=0; $i < @{$types}; $i++) {
		my $coefString = "";
		my @compounds = sort(keys(%{$compounds->{$types->[$i]}}));
		#Building coefficient strings and determining net mass for component types
		my $netMass = 0;
		for (my $j=0; $j < @compounds; $j++) {		
			my $objs = $self->figmodel()->database()->get_objects("compound",{id=>$compounds[$j]});
			my $mass = 0;
			if (defined($objs->[0]) && $objs->[0]->mass() != 0) {
				$mass = $objs->[0]->mass();
				$netMass += -$compounds->{$types->[$i]}->{$compounds[$j]}*$objs->[0]->mass();
			}
			if (!defined($equationCompounds->{$compounds[$j]})) {
				$equationCompounds->{$compounds[$j]}->{"coef"} = 0;
				$equationCompounds->{$compounds[$j]}->{"type"} = $types->[$i];
				$equationCompounds->{$compounds[$j]}->{"mass"} = $mass;
			}
			$coefString .= $compounds->{$types->[$i]}->{$compounds[$j]}."|";
		}
		$netMass = 0.001*$netMass;
		#Calculating coefficients for all component compounds
		for (my $j=0; $j < @compounds; $j++) {
			#Normalizing certain type coefficients by mass
			my $function = $types->[$i];
			my $fraction = $bioObj->$function();
			if ($types->[$i] ne "energy") {
				$fraction = $fraction/$netMass;
			}
			if ($compounds->{$types->[$i]}->{$compounds[$j]} eq 1e-5) {
				$fraction = 1;	
			}
			$equationCompounds->{$compounds[$j]}->{"coef"} += $fraction*$compounds->{$types->[$i]}->{$compounds[$j]};
		}
		chop($coefString);
		if (length($coefString) == 0) {
			$coefString = "NONE";
		}
		my $function = $types->[$i]."Coef";
		if ($types->[$i] ne "energy") {
			$bioObj->$function($coefString);
		}
	}
	#Adding biomass to compound list
	$equationCompounds->{cpd17041}->{coef} = -1;
	$equationCompounds->{cpd17041}->{type} = "macromolecule";
	$equationCompounds->{cpd17042}->{coef} = -1;
	$equationCompounds->{cpd17042}->{type} = "macromolecule";
	$equationCompounds->{cpd17043}->{coef} = -1;
	$equationCompounds->{cpd17043}->{type} = "macromolecule";
	$equationCompounds->{cpd11416}->{coef} = 1;
	$equationCompounds->{cpd11416}->{type} = "macromolecule";
	#Building equation from hash and populating compound biomass table
	my @compoundList = keys(%{$equationCompounds});
	my ($reactants,$products);
	#Deleting existing Biomass Compound info
	my $matchingObjs = $self->figmodel()->database()->get_objects("cpdbof",{BIOMASS=>$biomassID});
	for (my $i=0; $i < @{$matchingObjs}; $i++) {
		$matchingObjs->[$i]->delete();
	}
	my $typeCategories = {"macromolecule"=>"M","RNA"=>"R","DNA"=>"D","protein"=>"P","lipid"=>"L","cellWall"=>"W","cofactor"=>"C","energy"=>"E"};
	my $productmass = 0;
	my $reactantmass = 0;
	my $totalmass = 0;
	foreach my $compound (@compoundList) {
		if (defined($equationCompounds->{$compound}->{coef}) && defined($equationCompounds->{$compound}->{mass})) {
			$totalmass += $equationCompounds->{$compound}->{coef}*0.001*$equationCompounds->{$compound}->{mass};
		}
		if ($equationCompounds->{$compound}->{coef} < 0) {
			if (defined($equationCompounds->{$compound}->{coef}) && defined($equationCompounds->{$compound}->{mass})) {
				$reactantmass += $equationCompounds->{$compound}->{coef}*0.001*$equationCompounds->{$compound}->{mass};
			}
			$reactants->{$compound} = $self->figmodel()->format_coefficient(-1*$equationCompounds->{$compound}->{coef});
		} else {
			if (defined($equationCompounds->{$compound}->{coef}) && defined($equationCompounds->{$compound}->{mass})) {
				$productmass += $equationCompounds->{$compound}->{coef}*0.001*$equationCompounds->{$compound}->{mass};
			}
			$products->{$compound} = $self->figmodel()->format_coefficient($equationCompounds->{$compound}->{coef});
		}
		#Adding biomass reaction compounds to the biomass compound table
		$self->figmodel()->database()->create_object("cpdbof",{
			COMPOUND=>$compound,
			BIOMASS=>$biomassID,
			coefficient=>$equationCompounds->{$compound}->{coef},
			compartment=>"c",
			category=>$typeCategories->{$equationCompounds->{$compound}->{type}}
		});
	}
	print "Total mass = ".$totalmass.", Reactant mass = ".$reactantmass.", Product mass = ".$productmass."\n";
	my $Equation = "";
	my @ReactantList = sort(keys(%{$reactants}));
	for (my $i=0; $i < @ReactantList; $i++) {
		if (length($Equation) > 0) {
			$Equation .= " + ";
		}
		$Equation .= "(".$reactants->{$ReactantList[$i]}.") ".$ReactantList[$i];
	}
	$Equation .= " => ";
	my $First = 1;
	@ReactantList = sort(keys(%{$products}));
	for (my $i=0; $i < @ReactantList; $i++) {
		if ($First == 0) {
			$Equation .= " + ";
		}
		$First = 0;
		$Equation .= "(".$products->{$ReactantList[$i]}.") ".$ReactantList[$i];
	}
	$bioObj->equation($Equation);
	#Setting the biomass reaction of this model
	$self->biomassReaction($biomassID);
	$self->figmodel()->print_biomass_reaction_file($biomassID);
	#Checking if the biomass reaction remained unchanged
	if ($originalPackages ne "" && $originalPackages eq $bioObj->cofactorPackage().$bioObj->lipidPackage().$bioObj->cellWallPackage()) {
		print "UNCHANGED!\n";
		$bioObj->essentialRxn($originalEssReactions);
	} else {
		#Copying essential reaction lists if the packages in this biomasses reaction exactly match those in another biomass reaction
		my $matches = $self->figmodel()->database()->get_objects("bof",{
			cofactorPackage=>$bioObj->cofactorPackage(),
			lipidPackage=>$bioObj->lipidPackage(),
			cellWallPackage=>$bioObj->cellWallPackage()
		});
		my $matchFound = 0;
		for (my $i=0; $i < @{$matches}; $i++) {
			if ($matches->[$i]->id() ne $biomassID && defined($matches->[$i]->essentialRxn()) && length($matches->[$i]->essentialRxn())) {
				$bioObj->essentialRxn($matches->[$i]->essentialRxn());
				print "MATCH!\n";
				$matchFound = 1;
				last;
			}
		}
		#Otherwise, we calculate essential reactions
		if ($matchFound == 0) {
			print "NOMATCH!\n";
			$self->figmodel()->add_job_to_queue({
				command => "runfigmodelfunction?determine_biomass_essential_reactions?".$biomassID,
				user => $self->owner(),
				queue => "fast"
			});
		}
	}
	return $biomassID;
}

=head3 PrintSBMLFile
Definition:
	FIGMODELmodel->PrintSBMLFile();
Description:
	Printing file with model data in SBML format
=cut
sub PrintSBMLFile {
	my($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{print => 1});
	if (defined($args->{error})) {return $self->error_message({function => "PrintSBMLFile",args => $args});}
	#Loading and parsing the model data
	my $mdlTbl = $self->reaction_table();
	if (!defined($mdlTbl) || !defined($mdlTbl->{"array"})) {
		return $self->figmodel()->fail();
	}
	my $cmpTbl = $self->figmodel()->database()->get_table("COMPARTMENTS");
	#Adding intracellular metabolites that also need exchange fluxes to the exchange hash
	my $ExchangeHash = {"cpd11416" => "c"};
	my %CompartmentsPresent;
	$CompartmentsPresent{"c"} = 1;
	my %CompoundList;
	my @ReactionList;
	my $rxnHash = $self->figmodel()->database()->get_object_hash({
		type => "reaction",
		attribute => "id",
		-useCache => 1
	});
	for (my $i=0; $i < $mdlTbl->size(); $i++) {
		my $rxnObj;
		if ($mdlTbl->get_row($i)->{"LOAD"}->[0] =~ m/rxn\d\d\d\d\d/) {
			if (defined($rxnHash->{$mdlTbl->get_row($i)->{"LOAD"}->[0]})) {
				$rxnObj = $rxnHash->{$mdlTbl->get_row($i)->{"LOAD"}->[0]}->[0];
			}
		} elsif ($mdlTbl->get_row($i)->{"LOAD"}->[0] =~ m/bio\d\d\d\d\d/) {
			$rxnObj = $self->figmodel()->database()->get_object("bof",{id=>$mdlTbl->get_row($i)->{"LOAD"}->[0]});	
		}
		if (!defined($rxnObj)) {
			next;	
		}
		push(@ReactionList,$rxnObj);
		$_ = $rxnObj->equation();
		my @MatchArray = /(cpd\d\d\d\d\d)/g;
		for (my $j=0; $j < @MatchArray; $j++) {
			$CompoundList{$MatchArray[$j]}->{"c"} = 1;
		}
		$_ = $rxnObj->equation();
		@MatchArray = /(cpd\d\d\d\d\d\[\D\])/g;
		for (my $j=0; $j < @MatchArray; $j++) {
			if ($MatchArray[$j] =~ m/(cpd\d\d\d\d\d)\[(\D)\]/) {
				$CompartmentsPresent{lc($2)} = 1;
				$CompoundList{$1}->{lc($2)} = 1;
			}
		}
	}

	#Printing header to SBML file
	my $ModelName = $self->id().$self->selected_version();
	$ModelName =~ s/\./_/g;
	my $output;
	push(@{$output},'<?xml version="1.0" encoding="UTF-8"?>');
	push(@{$output},'<sbml xmlns="http://www.sbml.org/sbml/level2" level="2" version="1" xmlns:html="http://www.w3.org/1999/xhtml">');
	my $name = $self->id().$self->selected_version()." SEED model";
	if (defined($self->name())) {
		$name = $self->name()." SEED model";
	}
	$name =~ s/\s/_/g;
	push(@{$output},'<model id="'.$ModelName.'" name="'.$name.'">');

	#Printing the unit data
	push(@{$output},"<listOfUnitDefinitions>");
	push(@{$output},"\t<unitDefinition id=\"mmol_per_gDW_per_hr\">");
	push(@{$output},"\t\t<listOfUnits>");
	push(@{$output},"\t\t\t<unit kind=\"mole\" scale=\"-3\"/>");
	push(@{$output},"\t\t\t<unit kind=\"gram\" exponent=\"-1\"/>");
	push(@{$output},"\t\t\t<unit kind=\"second\" multiplier=\".00027777\" exponent=\"-1\"/>");
	push(@{$output},"\t\t</listOfUnits>");
	push(@{$output},"\t</unitDefinition>");
	push(@{$output},"</listOfUnitDefinitions>");

	#Printing compartments for SBML file
	push(@{$output},'<listOfCompartments>');
	foreach my $Compartment (keys(%CompartmentsPresent)) {
		my $row = $cmpTbl->get_row_by_key($Compartment,"Abbreviation");
		if (!defined($row) && !defined($row->{"Name"}->[0])) {
			next;
		}
		my @OutsideList = split(/\//,$row->{"Outside"}->[0]);
		my $Printed = 0;
		foreach my $Outside (@OutsideList) {
			if (defined($CompartmentsPresent{$Outside}) && defined($row->{"Name"}->[0])) {
				my $newRow = $cmpTbl->get_row_by_key($Outside,"Abbreviation");
				if (defined($newRow)) {
					push(@{$output},'<compartment id="'.$row->{"Name"}->[0].'" outside="'.$newRow->{"Name"}->[0].'"/>');
					$Printed = 1;
					last;
				}
   			}
   		}
   		if ($Printed eq 0) {
	   		push(@{$output},'<compartment id="'.$row->{"Name"}->[0].'"/>');
 		}
	}
	push(@{$output},'</listOfCompartments>');

	#Printing the list of metabolites involved in the model
	push(@{$output},'<listOfSpecies>');
	my $cpdHash = $self->figmodel()->database()->get_object_hash({
		type => "compound",
		attribute => "id",
		-useCache => 1
	});
	foreach my $Compound (keys(%CompoundList)) {
		my $cpdObj;
		if (defined($cpdHash->{$Compound})) {
			$cpdObj = $cpdHash->{$Compound}->[0];
		}
		if (!defined($cpdObj)) {
			next;	
		}
		my $Formula = "";
		if (defined($cpdObj->formula())) {
			$Formula = $cpdObj->formula();
		}
		my $Name = $cpdObj->name();
		$Name =~ s/\s/_/;
		$Name .= "_".$Formula;
		$Name =~ s/[<>;:&\*]//;
		my $Charge = 0;
		if (defined($cpdObj->charge())) {
			$Charge = $cpdObj->charge();
		}
		foreach my $Compartment (keys(%{$CompoundList{$Compound}})) {
			if ($Compartment eq "e") {
				$ExchangeHash->{$Compound} = "e";
			}
			my $cmprow = $cmpTbl->get_row_by_key($Compartment,"Abbreviation");
			push(@{$output},'<species id="'.$Compound.'_'.$Compartment.'" name="'.$Name.'" compartment="'.$cmprow->{"Name"}->[0].'" charge="'.$Charge.'" boundaryCondition="false"/>');
		}
	}
	
	#Printing the boundary species
	foreach my $Compound (keys(%{$ExchangeHash})) {
		my $cpdObj;
		if (defined($cpdHash->{$Compound})) {
			$cpdObj = $cpdHash->{$Compound}->[0];
		}
		if (!defined($cpdObj)) {
			next;	
		}
		my $Formula = "";
		if (defined($cpdObj->formula())) {
			$Formula = $cpdObj->formula();
		}
		my $Name = $cpdObj->name();
		$Name =~ s/\s/_/;
		$Name .= "_".$Formula;
		$Name =~ s/[<>;:&\*]//;
		my $Charge = 0;
		if (defined($cpdObj->charge())) {
			$Charge = $cpdObj->charge();
		}
		push(@{$output},'<species id="'.$Compound.'_b" name="'.$Name.'" compartment="Extracellular" charge="'.$Charge.'" boundaryCondition="true"/>');
	}
	push(@{$output},'</listOfSpecies>');

	#Printing the list of reactions involved in the model
	my $ObjectiveCoef;
	push(@{$output},'<listOfReactions>');
	my $mapTbl = $self->figmodel()->database()->get_table("KEGGMAPDATA");
	my $keggAliasHash = $self->figmodel()->database()->get_object_hash({
		type => "rxnals",
		attribute => "REACTION",
		parameters => {type=>"KEGG"},
		-useCache => 1
	});
	foreach my $rxnObj (@ReactionList) {
		$ObjectiveCoef = "0.0";
		my $mdlrow = $mdlTbl->get_row_by_key($rxnObj->id(),"LOAD");
		if ($rxnObj->id() =~ m/^bio/) {
			$ObjectiveCoef = "1.0";
		}
		my $LowerBound = -10000;
		my $UpperBound = 10000;
		my ($Reactants,$Products) = $self->figmodel()->get_reaction("rxn00001")->substrates_from_equation({equation=>$rxnObj->equation()});
		my $Name = $rxnObj->name();
		$Name =~ s/[<>;:&\*]//g;
		my $Reversibility = "true";
		if (defined($mdlrow->{"DIRECTIONALITY"}->[0])) {
			if ($mdlrow->{"DIRECTIONALITY"}->[0] ne "<=>") {
				$LowerBound = 0;
				$Reversibility = "false";
			}
			if ($mdlrow->{"DIRECTIONALITY"}->[0] eq "<=") {
				my $Temp = $Products;
				$Products = $Reactants;
				$Reactants = $Temp;
			}
		}
 		push(@{$output},'<reaction id="'.$rxnObj->id().'" name="'.$Name.'" reversible="'.$Reversibility.'">');
 		push(@{$output},"<notes>");
		my $ECData = "";
		if ($rxnObj->id() !~ m/^bio/) {
			if (defined($rxnObj->enzyme())) {
				my @ecList = split(/\|/,$rxnObj->enzyme());
				if (defined($ecList[1])) {
					$ECData = $ecList[1];
				}
			}
		}
		my $KEGGID = "";		
		if (defined($keggAliasHash->{$rxnObj->id()})) {
			$KEGGID = $keggAliasHash->{$rxnObj->id()}->[0]->alias();
		}
		my $KEGGMap = "";
		my @rows = $mapTbl->get_rows_by_key($rxnObj->id(),"REACTIONS");
		for (my $i=0; $i < @rows; $i++) {
			if ($i > 0) {
				$KEGGMap .= ";"
			}
			$KEGGMap .= $rows[$i]->{NAME}->[0];
		}
		my $SubsystemData = "";
		if (defined($mdlrow->{"SUBSYSTEM"}->[0])) {
			$SubsystemData = $mdlrow->{"SUBSYSTEM"}->[0];
		}
		my $GeneAssociation = "";
		my $ProteinAssociation = "";
		my $GeneLocus = "";
		my $GeneGI = "";
		if (defined($mdlrow->{"ASSOCIATED PEG"}->[0])) {
			if (@{$mdlrow->{"ASSOCIATED PEG"}} == 1 && $mdlrow->{"ASSOCIATED PEG"}->[0] !~ m/\+/) {
				$GeneAssociation = $mdlrow->{"ASSOCIATED PEG"}->[0];
				$GeneAssociation =~ s/\s//g;
			} else {
				if (@{$mdlrow->{"ASSOCIATED PEG"}} > 1) {
					$GeneAssociation = "( ";
				}
				for (my $i=0; $i < @{$mdlrow->{"ASSOCIATED PEG"}}; $i++) {
					if ($i > 0) {
						$GeneAssociation .= " )  or  ( ";
					}
					my $temp = $mdlrow->{"ASSOCIATED PEG"}->[$i];
					$temp =~ s/\s//g;
					$GeneAssociation .= $temp;
				}
				if (@{$mdlrow->{"ASSOCIATED PEG"}} > 1) {
					$GeneAssociation .= " )";
				}
			}
			$GeneAssociation =~ s/\+/  and  /g;
			if ($GeneAssociation =~ m/\sor\s/ || $GeneAssociation =~ m/\sand\s/) {
				$GeneAssociation = "( ".$GeneAssociation." )";
			}
			if (defined($self->genome())) {
				#($ProteinAssociation,$GeneLocus,$GeneGI) = $self->figmodel()->translate_gene_to_protein($mdlrow->{"ASSOCIATED PEG"},$self->genome());
			}
		}
		if (length($GeneAssociation) > 0) {
			push(@{$output},"<html:p>GENE_ASSOCIATION:".$GeneAssociation."</html:p>");
		}
		if (length($GeneLocus) > 0) {
			push(@{$output},"<html:p>GENE_LOCUS_TAG:".$GeneLocus."</html:p>");
		}
		if (length($GeneGI) > 0) {
			push(@{$output},"<html:p>GENE_GI:".$GeneGI."</html:p>");
		}
		if (length($ProteinAssociation) > 0) {
			push(@{$output},"<html:p>PROTEIN_ASSOCIATION:".$ProteinAssociation."</html:p>");
		}
		if (length($KEGGID) > 0) {
			push(@{$output},"<html:p>KEGG_RID:".$KEGGID."</html:p>");
		}
		if (length($KEGGMap) > 0) {
			push(@{$output},"<html:p>KEGG_MAP:".$KEGGMap."</html:p>");
		}
		if (length($SubsystemData) > 0 && $SubsystemData ne "NONE") {
			push(@{$output},"<html:p>SUBSYSTEM:".$SubsystemData."</html:p>");
		}
		if (length($ECData) > 0) {
			push(@{$output},"<html:p>PROTEIN_CLASS:".$ECData."</html:p>");
		}
 		push(@{$output},"</notes>");
 		if (defined($Reactants) && @{$Reactants} > 0) {
	 		push(@{$output},"<listOfReactants>");
	 		foreach my $Reactant (@{$Reactants}) {
	 			push(@{$output},'<speciesReference species="'.$Reactant->{"DATABASE"}->[0]."_".$Reactant->{"COMPARTMENT"}->[0].'" stoichiometry="'.$Reactant->{"COEFFICIENT"}->[0].'"/>');
	 		}
	 		push(@{$output},"</listOfReactants>");
 		}
 		if (defined($Products) && @{$Products} > 0) {
	 		push(@{$output},"<listOfProducts>");
			foreach my $Product (@{$Products}) {
	 			push(@{$output},'<speciesReference species="'.$Product->{"DATABASE"}->[0]."_".$Product->{"COMPARTMENT"}->[0].'" stoichiometry="'.$Product->{"COEFFICIENT"}->[0].'"/>');
	 		}
			push(@{$output},"</listOfProducts>");
 		}
		push(@{$output},"<kineticLaw>");
		push(@{$output},"\t<math xmlns=\"http://www.w3.org/1998/Math/MathML\">");
		push(@{$output},"\t\t\t<ci> FLUX_VALUE </ci>");
		push(@{$output},"\t</math>");
		push(@{$output},"\t<listOfParameters>");
		push(@{$output},"\t\t<parameter id=\"LOWER_BOUND\" value=\"".$LowerBound."\" units=\"mmol_per_gDW_per_hr\"/>");
		push(@{$output},"\t\t<parameter id=\"UPPER_BOUND\" value=\"".$UpperBound."\" units=\"mmol_per_gDW_per_hr\"/>");
		push(@{$output},"\t\t<parameter id=\"OBJECTIVE_COEFFICIENT\" value=\"".$ObjectiveCoef."\"/>");
		push(@{$output},"\t\t<parameter id=\"FLUX_VALUE\" value=\"0.0\" units=\"mmol_per_gDW_per_hr\"/>");
		push(@{$output},"\t</listOfParameters>");
		push(@{$output},"</kineticLaw>");
		push(@{$output},'</reaction>');
	}

	my @ExchangeList = keys(%{$ExchangeHash});
	foreach my $ExCompound (@ExchangeList) {
		my $cpdObj;
		if (defined($cpdHash->{$ExCompound})) {
			$cpdObj = $cpdHash->{$ExCompound}->[0];
		}
		if (!defined($cpdObj)) {
			next;	
		}
		my $ExCompoundName = $cpdObj->name();
		$ExCompoundName =~ s/[<>;&]//g;
		$ObjectiveCoef = "0.0";
		push(@{$output},'<reaction id="EX_'.$ExCompound.'_'.$ExchangeHash->{$ExCompound}.'" name="EX_'.$ExCompoundName.'_'.$ExchangeHash->{$ExCompound}.'" reversible="true">');
		push(@{$output},"\t".'<notes>');
		push(@{$output},"\t\t".'<html:p>GENE_ASSOCIATION: </html:p>');
		push(@{$output},"\t\t".'<html:p>PROTEIN_ASSOCIATION: </html:p>');
		push(@{$output},"\t\t".'<html:p>SUBSYSTEM: S_</html:p>');
		push(@{$output},"\t\t".'<html:p>PROTEIN_CLASS: </html:p>');
		push(@{$output},"\t".'</notes>');
		push(@{$output},"\t".'<listOfReactants>');
		push(@{$output},"\t\t".'<speciesReference species="'.$ExCompound.'_'.$ExchangeHash->{$ExCompound}.'" stoichiometry="1.000000"/>');
		push(@{$output},"\t".'</listOfReactants>');
		push(@{$output},"\t".'<listOfProducts>');
		push(@{$output},"\t\t".'<speciesReference species="'.$ExCompound.'_b" stoichiometry="1.000000"/>');
		push(@{$output},"\t".'</listOfProducts>');
		push(@{$output},"\t".'<kineticLaw>');
		push(@{$output},"\t\t".'<math xmlns="http://www.w3.org/1998/Math/MathML">');
		push(@{$output},"\t\t\t\t".'<ci> FLUX_VALUE </ci>');
		push(@{$output},"\t\t".'</math>');
		push(@{$output},"\t\t".'<listOfParameters>');
		push(@{$output},"\t\t\t".'<parameter id="LOWER_BOUND" value="-10000.000000" units="mmol_per_gDW_per_hr"/>');
		push(@{$output},"\t\t\t".'<parameter id="UPPER_BOUND" value="10000.000000" units="mmol_per_gDW_per_hr"/>');
		push(@{$output},"\t\t\t".'<parameter id="OBJECTIVE_COEFFICIENT" value="'.$ObjectiveCoef.'"/>');
		push(@{$output},"\t\t\t".'<parameter id="FLUX_VALUE" value="0.000000" units="mmol_per_gDW_per_hr"/>');
		push(@{$output},"\t\t".'</listOfParameters>');
		push(@{$output},"\t".'</kineticLaw>');
		push(@{$output},'</reaction>');
	}

	#Closing out the file
	push(@{$output},'</listOfReactions>');
	push(@{$output},'</model>');
	push(@{$output},'</sbml>');
	if ($args->{print} == 1) {
		$self->figmodel()->database()->print_array_to_file($self->directory().$self->id().".xml",$output);
	}
	return $output;
}
=head3 getSBMLFileReactions
Definition:
	Output:{} = FIGMODELmodel->getSBMLFileReactions({});
Description:
	Prints the table of model data
=cut
sub getSBMLFileReactions {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{});
	if (defined($args->{error})) {return $self->error_message({function => "generate_feature_data_table",args => $args});}
	my $data = $self->figmodel()->database()->load_single_column_file($self->directory().$self->id().".xml","");
	my $results;
	for (my $i=0; $i < @{$data}; $i++) {
		if ($data->[$i] =~ m/([rb][xi][no]\d\d\d\d\d)/) {
			$results->{SBMLreactons}->{$1} = 1;
		} elsif ($data->[$i] =~ m/(cpd\d\d\d\d\d)/) {
			$results->{SBMLcompounds}->{$1} = 1;
		}
	}
	my $rxnTbl = $self->reaction_table();
	for (my $i=0; $i < $rxnTbl->size(); $i++) {
		if (!defined($results->{SBMLreactons}->{$rxnTbl->get_row($i)->{LOAD}->[0]})) {
			$results->{missingReactons}->{$rxnTbl->get_row($i)->{LOAD}->[0]} = 1;
		}
	}
	my $cpdTbl = $self->compound_table();
	for (my $i=0; $i < $cpdTbl->size(); $i++) {
		if (!defined($results->{SBMLcompounds}->{$cpdTbl->get_row($i)->{DATABASE}->[0]})) {
			$results->{missingCompounds}->{$cpdTbl->get_row($i)->{DATABASE}->[0]} = 1;
		}
	}
	return $results;
}

=head3 PrintModelSimpleReactionTable
Definition:
	string:error message = FIGMODELmodel->PrintModelSimpleReactionTable();
Description:
	Prints the table of model data
=cut
sub PrintModelSimpleReactionTable {
	my ($self) = @_;
	my $rxntbl = $self->reaction_table();
	my $tbl = $self->create_table_prototype("ModelSimpleReactionTable");
	$tbl->prefix($self->id()."\n");
	for (my $i=0; $i < $rxntbl->size(); $i++) {
		my $row = $rxntbl->get_row($i);
		$row->{DATABASE} = $row->{LOAD};
		$tbl->add_row($row);
	}
	$tbl->save();
	if (-e $self->directory()."ReactionTbl-".$self->id().".txt") {
		system("rm ".$self->directory()."ReactionTbl-".$self->id().".txt");
	}
	system("cp ".$self->directory()."ReactionTbl-".$self->id().".tbl ".$self->directory()."ReactionTbl-".$self->id().".txt");
	return undef;
}
=head3 publicTable
Definition:
	FIGMODELTable = FIGMODELmodel->publicTable({type => R/C/F});
Description:
	This function prints the form of the reaction,compound,and gene tables that are used when generating the excel file for the metabolic models
=cut
sub publicTable {
    my ($self,$args) = @_;
    $args = $self->figmodel()->process_arguments($args,["type"],{});
	if (defined($args->{error})) {return $self->error_message({function => "publicTable",args => $args});}
    if ($args->{type} eq "R") {
    	return $self->generate_reaction_data_table($args);
    } elsif ($args->{type} eq "C") {
    	return $self->generate_compound_data_table($args);
    } elsif ($args->{type} eq "F") {
   		return $self->generate_feature_data_table($args);
    }
    return $self->error_message({message=>"Input type not recognized",function => "publicTable",args => $args});
}
=head3 reaction_table
Definition:
	FIGMODELTable = FIGMODELmodel->reaction_table();
Description:
	Returns FIGMODELTable with the reaction list for the model
=cut
sub reaction_table {
	my ($self,$clear) = @_;
	if (defined($clear) && $clear == 1) {
		delete $self->{_reaction_table};
	}
	if (!defined($self->{_reaction_table})) {
		$self->{_reaction_table} = $self->load_model_table("ModelReactions",$clear);
		my $classTbl = $self->reaction_class_table();
		if (defined($classTbl)) {
			for (my $i=0; $i < $classTbl->size(); $i++) {
				my $row = $classTbl->get_row($i);
				if (defined($row->{REACTION})) {
					my $rxnRow = $self->{_reaction_table}->get_row_by_key($row->{"REACTION"}->[0],"LOAD");
					if (defined($row->{MEDIA})) {
						for (my $j=0; $j < @{$row->{MEDIA}};$j++) {
							my $class = "Active <=>";
							if ($row->{CLASS}->[$j] eq "Positive") {
								$class = "Essential =>";
							} elsif ($row->{CLASS}->[$j] eq "Negative") {
								$class = "Essential <=";
							} elsif ($row->{CLASS}->[$j] eq "Blocked") {
								$class = "Inactive";
							} elsif ($row->{CLASS}->[$j] eq "Positive variable") {
								$class = "Active =>";
							} elsif ($row->{CLASS}->[$j] eq "Negative variable") {
								$class = "Active <=";
							} elsif ($row->{CLASS}->[$j] eq "Variable") {
								$class = "Active <=>";
							} elsif ($row->{CLASS}->[$j] eq "Dead") {
								$class = "Dead";
							}
							push(@{$rxnRow->{PREDICTIONS}},$row->{MEDIA}->[$j].":".$class);
						}
					}
				}
			}
		}
	}
	return $self->{_reaction_table};
}
=head3 generate_reaction_data_table
Definition:
	FIGMODELtable = FIGMODELmodel->generate_reaction_data_table({
		...
	});
Description:
	Creates a table of model reaction data
=cut
sub generate_reaction_data_table {
	my ($self,$args) = @_;
    $args = $self->figmodel()->process_arguments($args,[],{
    	-abbrev_eq => 0,
    	-name_eq => 1,
    	-id_eq => 1,
    	-direction => 1,
    	-compartment => 1,
    	-pegs => 1,
    	-roles => 0,
    	-notes => 0,
    	-kegg => 1,
    	-deltaG => 1,
    	-deltaGerr => 1,
    	-name => 1,
    	-EC => 1,
    	-subsystem => 0,
    	-reference => 0
    });
	if (defined($args->{error})) {return $self->error_message({function => "generate_reaction_data_table",args => $args});}
	my $headingArgHash = {
		EQUATION => "-id_eq",
		"ABBREVIATION EQ" => "-abbrev_eq",
		"NAME EQ" => "-name_eq",
		DIRECTION => "-direction",
		COMPARTMENT => "-compartment",
		ROLES => "-roles",
		PEGS => "-pegs",
		NOTES => "-notes",
		"KEGG ID(S)" => "-kegg",
		"DELTAG (kcal/mol)" => "-deltaG",
		"DELTAG ERROR (kcal/mol)" => "-deltaGerr",
		NAME => "-name",
		"EC NUMBER(S)" => "-ec",
		SUBSYSTEMS => "-subsystem",
		REFERENCE => "-reference"
	};
	my $headings = ["DATABASE"];
	#Temporarily removed these:"SUBSYSTEMS","NOTES","REFERECE"
	my $fullOrderedList = ["NAME","EC NUMBER(S)","KEGG ID(S)","DELTAG (kcal/mol)","DELTAG ERROR (kcal/mol)","EQUATION","ABBREVIATION EQ","NAME EQ","DIRECTION","COMPARTMENT","PEGS","ROLES"];
	foreach my $flag (@{$fullOrderedList}) {
		if (!defined($headingArgHash->{$flag}) || !defined($args->{$headingArgHash->{$flag}}) || $args->{$headingArgHash->{$flag}} == 1) {
			push(@{$headings},$flag);
		}
	}
	my $roleHash = $self->figmodel()->mapping()->get_role_rxn_hash();
	my $keggHash = $self->figmodel()->database()->get_object_hash({type=>"rxnals",attribute=>"REACTION",parameters=>{type=>"KEGG"},-useCache=>1});
	my $rxnHash = $self->figmodel()->database()->get_object_hash({type=>"reaction",attribute=>"id",-useCache=>1});
	my $rxntbl = $self->reaction_table();
	my $outputTbl = ModelSEED::FIGMODEL::FIGMODELTable->new($headings,$self->directory()."ReactionTable-".$self->id().".tbl",undef,"\t","|",undef);	
	for (my $i=0; $i < $rxntbl->size();$i++) {
		my $newRow;
		my $row = $rxntbl->get_row($i);
		my $obj;
		if (defined($rxnHash->{$row->{LOAD}->[0]})) {
			$obj = $rxnHash->{$row->{LOAD}->[0]}->[0];
		}
		my $biomass = 0;
		if (!defined($obj)) {
			$biomass = 1;
			$obj = $self->figmodel()->database()->get_object("bof",{id => $row->{LOAD}->[0]});
		}
		if (defined($obj)) {
			for (my $j=0; $j < @{$headings}; $j++) {
				if ($headings->[$j] eq "DATABASE") {
					$newRow->{$headings->[$j]}->[0] = $row->{LOAD}->[0];
				} elsif ($headings->[$j] eq "DIRECTION") {
					$newRow->{$headings->[$j]}->[0] = $row->{DIRECTIONALITY}->[0];
				} elsif ($headings->[$j] eq "COMPARTMENT") {
					$newRow->{$headings->[$j]}->[0] = $row->{COMPARTMENT}->[0];
				} elsif ($headings->[$j] eq "ROLES") {
					push(@{$newRow->{$headings->[$j]}},keys(%{$roleHash->{$row->{LOAD}->[0]}}));
				} elsif ($headings->[$j] eq "PEGS") {
					$newRow->{$headings->[$j]} = $row->{"ASSOCIATED PEG"};
				} elsif ($headings->[$j] eq "NOTES") {
					$newRow->{$headings->[$j]} = $row->{NOTES};
				} elsif ($headings->[$j] eq "REFERENCE") {
					$newRow->{$headings->[$j]} = $row->{REFERENCE};	
				} elsif ($headings->[$j] eq "EQUATION") {
					$newRow->{$headings->[$j]}->[0] = $self->get_reaction_equation({-id=>$row->{LOAD}->[0],-style=>"ID"});
				} elsif ($headings->[$j] eq "ABBREVIATION EQ") {
					$newRow->{$headings->[$j]}->[0] = $self->get_reaction_equation({-id=>$row->{LOAD}->[0],-style=>"ABBREV"});
				} elsif ($headings->[$j] eq "NAME EQ") {
					$newRow->{$headings->[$j]}->[0] = $self->get_reaction_equation({-id=>$row->{LOAD}->[0],-style=>"NAME"});
				} elsif ($headings->[$j] eq "KEGG ID(S)" && defined($keggHash->{$obj->id()})) {
					for (my $k=0; $k < @{$keggHash->{$obj->id()}}; $k++) {
						push(@{$newRow->{$headings->[$j]}},$keggHash->{$obj->id()}->[$k]->alias());
					}
				} elsif ($headings->[$j] eq "NAME") {
					$newRow->{$headings->[$j]}->[0] = $obj->name();
				} elsif ($headings->[$j] eq "EC NUMBER(S)" && $biomass == 0 && length($obj->enzyme()) > 2) {
					push(@{$newRow->{$headings->[$j]}},split(/\|/,substr($obj->enzyme(),1,length($obj->enzyme())-2)));
				} elsif ($headings->[$j] eq "DELTAG (kcal/mol)" && $biomass == 0) {
					$newRow->{$headings->[$j]}->[0] = $obj->deltaG();
				} elsif ($headings->[$j] eq "DELTAG ERROR (kcal/mol)" && $biomass == 0) {
					$newRow->{$headings->[$j]}->[0] = $obj->deltaGErr();
				} elsif ($headings->[$j] eq "SUBSYSTEMS" && $biomass == 0) {
					#TODO
					$newRow->{$headings->[$j]}->[0] = "NONE";
				}
			}
			$outputTbl->add_row($newRow);
		}
	}
	return $outputTbl;
}
=head3 compound_table
Definition:
	FIGMODELTable = FIGMODELmodel->compound_table();
Description:
	Returns FIGMODELTable with the compound list for the model
=cut
sub compound_table {
	my ($self) = @_;
	if (!defined($self->{_compound_table})) {
		$self->{_compound_table} = $self->create_table_prototype("ModelCompounds");
		#Loading the model
		my $ModelTable = $self->reaction_table();
		#Checking that the tables were loaded
		if (!defined($ModelTable)) {
			return undef;
		}
		#Finding the biomass reaction
		for (my $i=0; $i < $ModelTable->size(); $i++) {
			my $ID = $ModelTable->get_row($i)->{"LOAD"}->[0];
			my $obj = $self->figmodel()->database()->get_object("reaction",{id => $ID});
			my $IsBiomass = 0;
			if (!defined($obj)) {
				$obj = $self->figmodel()->database()->get_object("bof",{id => $ID});
				$IsBiomass = 1;
			}
			if (defined($obj)) {
				if (defined($obj->equation())) {
					$_ = $obj->equation();
					my @OriginalArray = /(cpd\d\d\d\d\d[\[\w]*)/g;
					foreach my $Compound (@OriginalArray) {
						my $cpdID = substr($Compound,0,8);
						my $NewRow = $self->{_compound_table}->get_row_by_key($cpdID,"DATABASE",1);
						if ($IsBiomass == 1) {
							$self->{_compound_table}->add_data($NewRow,"BIOMASS",$ID,1);
						}
						if (length($Compound) > 8) {
							my $Compartment = substr($Compound,9,1);
							$self->{_compound_table}->add_data($NewRow,"COMPARTMENTS",$Compartment,1);
							$self->{_compound_table}->add_data($NewRow,"TRANSPORTERS",$ID,1);
						} else {
							$self->{_compound_table}->add_data($NewRow,"COMPARTMENTS","c",1);
						}
					}
				}
			}
		}
	}
	return $self->{_compound_table};
}
=head3 generate_compound_data_table
Definition:
	FIGMODELtable = FIGMODELmodel->generate_compound_data_table({
		...
	});
Description:
	Creates a table of model compound data
=cut
sub generate_compound_data_table {
	my ($self,$args) = @_;
    $args = $self->figmodel()->process_arguments($args,[],{
    	-formula => 1,
    	-mass => 1,
    	-primname => 1,
    	-charge => 1,
    	-abbrev => 1,
    	-name => 1,
    	-kegg => 1,
    	-deltaG => 1,
    	-deltaGerr => 1,
    	-biomass => 1,
    	-compartments => 1
    });
	if (defined($args->{error})) {return $self->error_message({function => "generate_compound_data_table",args => $args});}
	my $headingArgHash = {
		FORMULA => "-formula",
		MASS => "-mass",
		"PRIMARY NAME" => "-primname",
		CHARGE => "-charge",
		ABBREVIATION => "-abbrev",
		NAMES => "-name",
		"KEGG ID(S)" => "-kegg",
		"DELTAG (kcal/mol)" => "-deltaG",
		"DELTAG ERROR (kcal/mol)" => "-deltaGerr",
		BIOMASS => "-biomass",
    	COMPARTMENTS => "-compartments"
	};
	my $headings = ["DATABASE"];
	my $fullOrderedList = ["PRIMARY NAME","ABBREVIATION","NAMES","KEGG ID(S)","FORMULA","CHARGE","DELTAG (kcal/mol)","DELTAG ERROR (kcal/mol)","MASS"];
	foreach my $flag (@{$fullOrderedList}) {
		if (!defined($headingArgHash->{$flag}) || !defined($args->{$headingArgHash->{$flag}}) || $args->{$headingArgHash->{$flag}} == 1) {
			push(@{$headings},$flag);
		}
	}
	my $keggHash = $self->figmodel()->database()->get_object_hash({type=>"cpdals",attribute=>"COMPOUND",parameters=>{type => "KEGG"},-useCache=>1});
	my $nameHash = $self->figmodel()->database()->get_object_hash({type=>"cpdals",attribute=>"COMPOUND",parameters=>{type => "name"},-useCache=>1});
	my $cpdHash = $self->figmodel()->database()->get_object_hash({type=>"compound",attribute=>"id"},-useCache=>1);
	my $cpdtbl = $self->compound_table();
	my $outputTbl = ModelSEED::FIGMODEL::FIGMODELTable->new($headings,$self->directory()."CompoundTable-".$self->id().".tbl",undef,"\t","|",undef);	
	for (my $i=0; $i < $cpdtbl->size();$i++) {
		my $newRow;
		my $row = $cpdtbl->get_row($i);
		my $obj;
		if (defined($cpdHash->{$row->{DATABASE}->[0]})) {
			$obj = $cpdHash->{$row->{DATABASE}->[0]}->[0];
		}
		if (defined($obj)) {
			for (my $j=0; $j < @{$headings}; $j++) {
				if ($headings->[$j] eq "DATABASE") {
					$newRow->{$headings->[$j]}->[0] = $row->{DATABASE}->[0];
				} elsif ($headings->[$j] eq "FORMULA" && defined($obj)) {
					$newRow->{$headings->[$j]}->[0] = $obj->formula();
				} elsif ($headings->[$j] eq "MASS" && defined($obj)) {
					$newRow->{$headings->[$j]}->[0] = $obj->mass();
				} elsif ($headings->[$j] eq "CHARGE" && defined($obj)) {
					$newRow->{$headings->[$j]}->[0] = $obj->charge();
				} elsif ($headings->[$j] eq "PRIMARY NAME" && defined($obj)) {
					$newRow->{$headings->[$j]}->[0] = $obj->name();
				} elsif ($headings->[$j] eq "ABBREVIATION" && defined($obj)) {
					$newRow->{$headings->[$j]}->[0] = $obj->abbrev();
				} elsif ($headings->[$j] eq "KEGG ID(S)" && defined($keggHash->{$obj->id()})) {
					for (my $k=0; $k < @{$keggHash->{$obj->id()}}; $k++) {
						push(@{$newRow->{$headings->[$j]}},$keggHash->{$obj->id()}->[$k]->alias());
					}
				} elsif ($headings->[$j] eq "DELTAG (kcal/mol)" && defined($obj)) {
					$newRow->{$headings->[$j]}->[0] = $obj->deltaG();
				} elsif ($headings->[$j] eq "DELTAG ERROR (kcal/mol)" && defined($obj)) {
					$newRow->{$headings->[$j]}->[0] = $obj->deltaGErr();
				} elsif ($headings->[$j] eq "COMPARTMENTS" && defined($row->{COMPARTMENTS})) {
					$newRow->{$headings->[$j]} = $row->{COMPARTMENTS};
				} elsif ($headings->[$j] eq "BIOMASS" && defined($row->{BIOMASS})) {
					$newRow->{$headings->[$j]}->[0] = "yes";
				} elsif ($headings->[$j] eq "NAMES" && defined($nameHash->{$row->{DATABASE}->[0]})) {
					for (my $k=0; $k < @{$nameHash->{$row->{DATABASE}->[0]}}; $k++) {
						push(@{$newRow->{$headings->[$j]}},$nameHash->{$row->{DATABASE}->[0]}->[$k]->alias());
					}
				}
			}
		}
		$outputTbl->add_row($newRow);	
	}
	return $outputTbl;
}
=head3 feature_table
Definition:
	FIGMODELTable = FIGMODELmodel->feature_table();
Description:
	Returns FIGMODELTable with the feature list for the model
=cut
sub feature_table {
	my ($self) = @_;
	if (!defined($self->{_feature_data})) {
		#Getting the genome feature list
		my $FeatureTable = $self->figmodel()->GetGenomeFeatureTable($self->genome());
		if (!defined($FeatureTable)) {
			print STDERR "FIGMODELmodel:feature_table:Could not get features for genome ".$self->genome()." in database!";
			return undef;
		}
		#Getting the reaction table for the model
		my $rxnTable = $self->reaction_table();
		if (!defined($rxnTable)) {
			print STDERR "FIGMODELmodel:feature_table:Could not get reaction table for model ".$self->id()." in database!";
			return undef;
		}
		#Cloning the feature table
		$self->{_feature_data} = $FeatureTable->clone_table_def();
		$self->{_feature_data}->add_headings(($self->id()."REACTIONS",$self->id()."PREDICTIONS"));
		for (my $i=0; $i < $rxnTable->size(); $i++) {
			my $Row = $rxnTable->get_row($i);
			if (defined($Row) && defined($Row->{"ASSOCIATED PEG"})) {
				foreach my $GeneSet (@{$Row->{"ASSOCIATED PEG"}}) {
					my $temp = $GeneSet;
					$temp =~ s/\+/|/g;
	  				$temp =~ s/\sAND\s/|/gi;
	  				$temp =~ s/\sOR\s/|/gi;
	  				$temp =~ s/[\(\)\s]//g;
	  				my @GeneList = split(/\|/,$temp);
	  				foreach my $Gene (@GeneList) {
	  					my $FeatureRow = $self->{_feature_data}->get_row_by_key("fig|".$self->genome().".".$Gene,"ID");
				  		if (!defined($FeatureRow)) {
							$FeatureRow = $FeatureTable->get_row_by_key("fig|".$self->genome().".".$Gene,"ID");
							if (defined($FeatureRow)) {
								$self->{_feature_data}->add_row($FeatureRow);
							}
				  		}
				 		if (defined($FeatureRow)) {
							$self->{_feature_data}->add_data($FeatureRow,$self->id()."REACTIONS",$Row->{"LOAD"}->[0],1);
				  		}
	  				}
				}
	  		}
		}
		#Loading predictions
		my $objects = $self->figmodel()->database()->get_objects("mdless",{parameters=>"NONE",MODEL=>$self->id()});
		my $mediaHash;
		for (my $i=0; $i < @{$objects}; $i++) {
			my @list = split(/;/,$objects->[$i]->essentials());
			for (my $j=0; $j < @list; $j++) {
				$mediaHash->{$objects->[$i]->MEDIA()}->{$list[$j]} = 1;
			}
		}
		for (my $i=0; $i < $self->{_feature_data}->size(); $i++) {
			my $Row = $self->{_feature_data}->get_row($i);
			if ($Row->{ID}->[0] =~ m/(peg\.\d+)/) {
				my $gene = $1;
				foreach my $media (keys(%{$mediaHash})) {
					if (defined($mediaHash->{$media}->{$gene})) {
						push(@{$Row->{$self->id()."PREDICTIONS"}},$media.":essential");
					} else {
						push(@{$Row->{$self->id()."PREDICTIONS"}},$media.":nonessential");
					}
				}
			}
		}
	}
	return $self->{_feature_data};
}
=head3 generate_feature_data_table
Definition:
	FIGMODELtable = FIGMODELmodel->generate_feature_data_table({
		...
	});
Description:
	Creates a table of model compound data
=cut
sub generate_feature_data_table {
	my ($self,$args) = @_;
    $args = $self->figmodel()->process_arguments($args,[],{
    	-start => 1,
    	-stop => 1,
    	-direction => 1,
    	-annotation => 1,
    	-subsystems => 1,
    	-reactions => 1,
    	-predictedEssentiality => 1
    });
	if (defined($args->{error})) {return $self->error_message({function => "generate_feature_data_table",args => $args});}
	my $headingArgHash = {
		START => "-start",
		STOP => "-stop",
		DIRECTION => "-direction",
		ANNOTATION => "-annotation",
		SUBSYSTEMS => "-subsystems",
		REACTIONS => "-reactions",
		"PREDICTED ESSENTIALITY" => "-predictedEssentiality"
	};
	my $headings = ["SEED GENE ID"];
	my $fullOrderedList = ["START","STOP","DIRECTION","ANNOTATION","SUBSYSTEMS","REACTIONS","PREDICTED ESSENTIALITY"];
	foreach my $flag (@{$fullOrderedList}) {
		if (!defined($headingArgHash->{$flag}) || !defined($args->{$headingArgHash->{$flag}}) || $args->{$headingArgHash->{$flag}} == 1) {
			push(@{$headings},$flag);
		}
	}
	my $ftrTbl = $self->feature_table();
	my $outputTbl = ModelSEED::FIGMODEL::FIGMODELTable->new($headings,$self->directory()."FeatureTable-".$self->id().".tbl",undef,"\t","|",undef);	
	for (my $i=0; $i < $ftrTbl->size();$i++) {
		my $newRow;
		my $row = $ftrTbl->get_row($i);
		if ($row->{ID}->[0] =~ m/peg/) {
			for (my $j=0; $j < @{$headings}; $j++) {
				if ($headings->[$j] eq "SEED GENE ID") {
					$newRow->{$headings->[$j]}->[0] = $row->{ID}->[0];
				} elsif ($headings->[$j] eq "START") {
					$newRow->{$headings->[$j]}->[0] = $row->{"MIN LOCATION"}->[0];
				} elsif ($headings->[$j] eq "STOP") {
					$newRow->{$headings->[$j]}->[0] = $row->{"MAX LOCATION"}->[0];
				} elsif ($headings->[$j] eq "DIRECTION") {
					$newRow->{$headings->[$j]}->[0] = $row->{DIRECTION}->[0];
				} elsif ($headings->[$j] eq "ANNOTATION") {
					$newRow->{$headings->[$j]} = $row->{ROLES};
				} elsif ($headings->[$j] eq "SUBSYSTEMS") {
					#TODO
					$newRow->{$headings->[$j]}->[0] = "";
				} elsif ($headings->[$j] eq "REACTIONS" && defined($row->{$self->id()."REACTIONS"})) {
					$newRow->{$headings->[$j]} = $row->{$self->id()."REACTIONS"};
				} elsif ($headings->[$j] eq "PREDICTED ESSENTIALITY" && defined($row->{$self->id()."PREDICTIONS"})) {
					$newRow->{$headings->[$j]} = $row->{$self->id()."PREDICTIONS"};
				}
			}
			$outputTbl->add_row($newRow);
		}
	}
	return $outputTbl;
}
=head3 PrintModelLPFile
Definition:
	success()/fail() FIGMODELmodel->PrintModelLPFile();
Description:
	Prints the lp file needed to run the model using the mpifba program
=cut
sub PrintModelLPFile {
	my ($self,$exportForm) = @_;
	#Printing lp and key file for model
	my $UniqueFilename = $self->figmodel()->filename();
	#Printing the standard FBA file
	if (defined($exportForm) && $exportForm eq "1") {
		system($self->figmodel()->GenerateMFAToolkitCommandLineCall($UniqueFilename,$self->id(),"NoBounds",["ProdFullFBALP"],{"Make all reactions reversible in MFA"=>0,"use simple variable and constraint names"=>0},$self->id().$self->selected_version()."-LPPrint.log",undef,$self->selected_version()));
		system("cp ".$self->config("MFAToolkit output directory")->[0].$UniqueFilename."/CurrentProblem.lp ".$self->directory().$self->id().$self->selected_version().".lp");
	} else {
		system($self->figmodel()->GenerateMFAToolkitCommandLineCall($UniqueFilename,$self->id(),"NoBounds",["ProdFullFBALP"],undef,$self->id().$self->selected_version()."-LPPrint.log",undef,$self->selected_version()));
		system("cp ".$self->config("MFAToolkit output directory")->[0].$UniqueFilename."/CurrentProblem.lp ".$self->directory()."FBA-".$self->id().$self->selected_version().".lp");
	}
	my $KeyTable = ModelSEED::FIGMODEL::FIGMODELTable::load_table($self->config("MFAToolkit output directory")->[0].$UniqueFilename."/VariableKey.txt",";","|",0,undef);
	if (!defined($KeyTable)) {
		print STDERR "FIGMODEL:RunAllStudiesWithDataFast: ".$self->id()." LP file could not be printed.\n";
		return 0;
	}
	$KeyTable->headings(["Variable type","Variable ID"]);
	$KeyTable->save($self->directory()."FBA-".$self->id().$self->selected_version().".key");
	unlink($self->config("database message file directory")->[0].$self->id().$self->selected_version()."-LPPrint.log");
	$self->figmodel()->clearing_output($UniqueFilename,"FBA-".$self->id().$self->selected_version().".lp");
}

=head3 patch_model
Definition:
	FIGMODELmodel->patch_model([] -or- {} of patch arguments);
Description:
=cut
sub patch_model {
	my ($self,$arguments) = @_;
	my $rxnTbl = $self->reaction_table();
	my $hash = $self->figmodel()->database()->get_object_hash({
		type => "reaction",
		attribute => "id",
	});
	for (my $i=0; $i < $rxnTbl->size(); $i++) {
		my $row = $rxnTbl->get_row($i);
		if (!defined($hash->{$row->{LOAD}->[0]}) && $row->{LOAD}->[0] !~ m/bio/) {
			$self->globalMessage({
				function => "patch_model",
				message => "bad reacton ".$row->{LOAD}->[0],
				thread => "stdout"
			});
		}
	}
	my $row = $rxnTbl->get_row_by_key("rxn10821","LOAD");
	if (defined($row)) {
		$self->removeReactions({
			ids => ["rxn10821"],
			compartments => ["c"],
			reason => "replacing rxn10821 with equivalent reaction rxn05513",
			user => "chenry",
			trackChanges => 1
		});
		$self->add_reactions({
	    	ids => ["rxn05513"],
	    	directionalitys => [$row->{DIRECTIONALITY}->[0]],
	    	compartments => [$row->{COMPARTMENT}->[0]],
	    	pegs => [$row->{"ASSOCIATED PEG"}],
	    	subsystems => [$row->{SUBSYSTEM}],
	    	confidences => [$row->{CONFIDENCE}->[0]],
	    	references => [$row->{REFERENCE}],
	    	notes => [$row->{NOTES}],
	    	reason => "replacing rxn10821 with equivalent reaction rxn05513",
	    	user => "chenry",
	    	adjustmentOnly => 0,
	    	transaction => undef
	    });
	}
}

=head3 integrateUploadedChanges
Definition:
	FIGMODELmodel->integrateUploadedChanges();
Description:
=cut
sub integrateUploadedChanges {
	my ($self,$username) = @_;
	if (!-e $self->directory().$self->id()."-uploadtable.tbl") {
		$self->error_message("integrateUploadedChanges:uploaded file not found for model!");
		return undef;
	}
	my $tbl = $self->load_model_table("ModelReactionUpload",1);
	if (!defined($tbl)) {
		$self->error_message("integrateUploadedChanges:could not load uploaded reaction table!");
		return undef;
	}
	if (substr($tbl->prefix(),0,length($self->id())) ne $self->id()) {
		$self->error_message("integrateUploadedChanges:model labeled in uploaded file does not match reference model!");
		return undef;
	}
	my $newrxntbl = $self->reaction_table(1);
	if (!defined($newrxntbl)) {
		$self->error_message("integrateUploadedChanges:could not load reaction table!");
		return undef;
	}
	for (my $i=0; $i < $newrxntbl->size(); $i++) {
		my $row = $newrxntbl->get_row($i);
		my $newrow = $tbl->get_row_by_key($row->{LOAD}->[0],"DATABASE");
		if (!defined($newrow)) {
			$newrxntbl->delete_row($i);
			$i--;
		} else {
			$row->{DIRECTIONALITY} = $newrow->{DIRECTIONALITY};
			$row->{COMPARTMENT} = $newrow->{COMPARTMENT};
			$row->{"ASSOCIATED PEG"} = $newrow->{"ASSOCIATED PEG"};
			$row->{NOTES} = $newrow->{NOTES};
		}
	}
	for (my $i=0; $i < $tbl->size(); $i++) {
		my $row = $tbl->get_row($i);
		my $newrow = $newrxntbl->get_row_by_key($row->{DATABASE}->[0],"LOAD");
		if (!defined($newrow)) {
			$newrxntbl->add_row({LOAD=>$row->{DATABASE},DIRECTIONALITY=>$row->{DIRECTIONALITY},COMPARTMENT=>$row->{COMPARTMENT},"ASSOCIATED PEG"=>$row->{"ASSOCIATED PEG"},SUBSYSTEM=>["NONE"],CONFIDENCE=>[5],REFERENCE=>["NONE"],NOTES=>$row->{NOTES}});
		}
	}
	$self->calculate_model_changes($self->reaction_table(1),$username." modifications",$newrxntbl);
	$newrxntbl->save();
	$self->PrintSBMLFile();
	$self->PrintModelLPFile();
	$self->PrintModelLPFile(1);
	$self->PrintModelSimpleReactionTable();
	$self->update_model_stats();
	$self->calculate_growth()
}

=head3 translate_genes
Definition:
	FIGMODELmodel->translate_genes();
Description:
=cut
sub translate_genes {
	my ($self) = @_;
	
	#Loading gene translations
	if (!defined($self->{_gene_aliases})) {
		#Loading gene aliases from feature table
		my $tbl = $self->figmodel()->GetGenomeFeatureTable($self->genome());
		if (defined($tbl)) {
			for (my $i=0; $i < $tbl->size(); $i++) {
				my $row = $tbl->get_row($i);
				if ($row->{ID}->[0] =~ m/(peg\.\d+)/) {
					my $geneID = $1;
					for (my $j=0; $j < @{$row->{ALIASES}}; $j++) {
						$self->{_gene_aliases}->{$row->{ALIASES}->[$j]} = $geneID;
					}
				}
			}
		}
		#Loading additional gene aliases from the database
		if (-e $self->figmodel()->config("Translation directory")->[0]."AdditionalAliases/".$self->genome().".txt") {
			my $AdditionalAliases = $self->figmodel()->database()->load_multiple_column_file($self->figmodel()->config("Translation directory")->[0]."AdditionalAliases/".$self->genome().".txt","\t");
			for (my $i=0; $i < @{$AdditionalAliases}; $i++) {
				$self->{_gene_aliases}->{$AdditionalAliases->[$i]->[1]} = $AdditionalAliases->[$i]->[0];
			}
		}
	}
	
	#Cycling through reactions and translating genes
	for (my $i=0; $i < $self->reaction_table()->size(); $i++) {
		my $row = $self->reaction_table()->get_row($i);
		if (defined($row->{"ASSOCIATED PEG"})) {
			for (my $j=0; $j < @{$row->{"ASSOCIATED PEG"}}; $j++) {
				my $Original = $row->{"ASSOCIATED PEG"}->[$j];
				$Original =~ s/\sand\s/:/g;
				$Original =~ s/\sor\s/;/g;
				my @GeneNames = split(/[,\+\s\(\):;]/,$Original);
				foreach my $Gene (@GeneNames) {
					if (length($Gene) > 0 && defined($self->{_gene_aliases}->{$Gene})) {
						my $Replace = $self->{_gene_aliases}->{$Gene};
						$Original =~ s/([^\w])$Gene([^\w])/$1$Replace$2/g;
						$Original =~ s/^$Gene([^\w])/$Replace$1/g;
						$Original =~ s/([^\w])$Gene$/$1$Replace/g;
						$Original =~ s/^$Gene$/$Replace/g;
					}
				}
				$Original =~ s/:/ and /g;
				$Original =~ s/;/ or /g;
				$row->{"ASSOCIATED PEG"}->[$j] = $Original;
			}
		}
	}
	
	#Archiving model and saving reaction table
	$self->ArchiveModel();
	$self->reaction_table()->save();
}

=head3 feature_web_data
Definition:
	string:web output for feature/model connection = FIGMODELmodel->feature_web_data(FIGMODELfeature:feature);
Description:
=cut
sub feature_web_data {
	my ($self,$feature) = @_;
	#First checking if the feature is in the model
	if (!defined($feature->{$self->id()})) {
		return "Not in model";	
	}
	my $output;
	if (defined($feature->{$self->id()}->{reactions})) {
		my @reactionList = keys(%{$feature->{$self->id()}->{reactions}});
		for (my $i=0; $i < @reactionList; $i++) {
			my $rxnData = $self->get_reaction_data($reactionList[$i]);
			my $reactionString = $self->figmodel()->web()->create_reaction_link($reactionList[$i],join(" or ",@{$rxnData->{"ASSOCIATED PEG"}}),$self->id());
			if (defined($rxnData->{PREDICTIONS})) {
				my $predictionHash;
				for (my $i=0; $i < @{$rxnData->{PREDICTIONS}};$i++) {
					my @temp = split(/:/,$rxnData->{PREDICTIONS}->[$i]); 
					push(@{$predictionHash->{$temp[1]}},$temp[0]);
				}
				$reactionString .= "(";
				foreach my $key (keys(%{$predictionHash})) {
					if ($key eq "Essential =>") {
						$reactionString .= '<span title="Essential in '.join(",",@{$predictionHash->{$key}}).'">E=></span>,';
					} elsif ($key eq "Essential <=") {
						$reactionString .= '<span title="Essential in '.join(",",@{$predictionHash->{$key}}).'">E<=</span>,';
					} elsif ($key eq "Active =>") {
						$reactionString .= '<span title="Active in '.join(",",@{$predictionHash->{$key}}).'">A=></span>,';
					} elsif ($key eq "Active <=") {
						$reactionString .= '<span title="Active in '.join(",",@{$predictionHash->{$key}}).'">A<=</span>,';
					} elsif ($key eq "Active <=>") {
						$reactionString .= '<span title="Active in '.join(",",@{$predictionHash->{$key}}).'">A</span>,';
					} elsif ($key eq "Inactive") {
						$reactionString .= '<span title="Inactive in '.join(",",@{$predictionHash->{$key}}).'">I</span>,';
					} elsif ($key eq "Dead") {
						$reactionString .= '<span title="Dead">D</span>,';
					}
				}
				$reactionString =~ s/,$/)/;
			}
			push(@{$output},$reactionString);
		}
	}
	if (defined($feature->{$self->id()}->{essentiality})) {
		my $essDataHash;
		if (defined($feature->{ESSENTIALITY})) {
			for (my $i=0; $i < @{$feature->{ESSENTIALITY}};$i++) {
				my @array = split(/:/,$feature->{ESSENTIALITY}->[$i]);
				$essDataHash->{$array[0]} = $array[1];
			}
		}
		my @mediaList = keys(%{$feature->{$self->id()}->{essentiality}});
		my $predictionHash;
		for(my $i=0; $i < @mediaList; $i++) {
			if (defined($essDataHash->{$mediaList[$i]})) {
				if ($essDataHash->{$mediaList[$i]} eq "essential") {
					if ($feature->{$self->id()}->{essentiality}->{$mediaList[$i]} == 0) {
						push(@{$predictionHash->{"False positive"}},$mediaList[$i]);	
					} elsif ($feature->{$self->id()}->{essentiality}->{$mediaList[$i]} == 1) {
						push(@{$predictionHash->{"Correct negative"}},$mediaList[$i]);
					}
				} else {
					if ($feature->{$self->id()}->{essentiality}->{$mediaList[$i]} == 0) {
						push(@{$predictionHash->{"Correct positive"}},$mediaList[$i]);	
					} elsif ($feature->{$self->id()}->{essentiality}->{$mediaList[$i]} == 1) {
						push(@{$predictionHash->{"False negative"}},$mediaList[$i]);
					}
				}
			} elsif ($feature->{$self->id()}->{essentiality}->{$mediaList[$i]} == 0) {
				push(@{$predictionHash->{"Nonessential"}},$mediaList[$i]);	
			} elsif ($feature->{$self->id()}->{essentiality}->{$mediaList[$i]} == 1) {
				push(@{$predictionHash->{"Essential"}},$mediaList[$i]);
			}
		}
		my @predictions = keys(%{$predictionHash});
		for(my $i=0; $i < @predictions; $i++) {
			my $predictionString = '<span title="'.$predictions[$i].' in '.join(",",@{$predictionHash->{$predictions[$i]}}).'">'.$predictions[$i].'</span>';
			push(@{$output},$predictionString);
		}
	}	
	#Returning output
	return join("<br>",@{$output});
}

=head3 remove_obsolete_reactions
Definition:
	void FIGMODELmodel->remove_obsolete_reactions();
Description:
=cut
sub remove_obsolete_reactions {
	my ($self) = @_;
	
	(my $dummy,my $translation) = $self->figmodel()->put_two_column_array_in_hash($self->figmodel()->database()->load_multiple_column_file($self->figmodel()->config("Translation directory")->[0]."ObsoleteRxnIDs.txt","\t"));
	my $rxnTbl = $self->reaction_table();
	if (defined($rxnTbl)) {
		for (my $i=0; $i < $rxnTbl->size(); $i++) {
			my $row = $rxnTbl->get_row($i);
			if (defined($translation->{$row->{LOAD}->[0]}) || defined($translation->{$row->{LOAD}->[0]."r"})) {
				my $direction = $row->{DIRECTION}->[0];
				my $newRxn;
				if (defined($translation->{$row->{LOAD}->[0]."r"})) {
					$newRxn = $translation->{$row->{LOAD}->[0]."r"};
					if ($direction eq "<=") {
						$direction = "=>";
					} elsif ($direction eq "=>") {
						$direction = "<=";
					}
				} else {
					$newRxn = $translation->{$row->{LOAD}->[0]};
				}
				#Checking if the new reaction is already in the model
				my $newRow = $rxnTbl->get_row_by_key($newRxn,"LOAD");
				if (defined($newRow)) {
					#Handling direction
					if ($newRow->{DIRECTION}->[0] ne $direction) {
						$newRow->{DIRECTION}->[0] = "<=>";
					}
					push(@{$row->{"ASSOCIATED PEG"}},@{$rxnTbl->get_row($i)->{"ASSOCIATED PEG"}});
				} else {
					$rxnTbl->get_row($i)->{LOAD}->[0] = $newRxn;
					$rxnTbl->get_row($i)->{DIRECTION}->[0] = $direction;
				}
			}
		}
		$rxnTbl->save();
	}
}

=pod

=item * [string]:I<list of essential genes> = B<run_geneKO_slow> (string:I<media>,0/1:I<max growth>,0/1:I<save results>);

=cut

sub run_geneKO_slow {
	my ($self,$media,$maxGrowth,$save) = @_;
	my $output;
	my $UniqueFilename = $self->figmodel()->filename();
	if (defined($maxGrowth) && $maxGrowth == 1) {
		system($self->figmodel()->GenerateMFAToolkitCommandLineCall($UniqueFilename,$self->id(),$media,["ProductionMFA"],{"perform single KO experiments" => 1,"MFASolver" => "GLPK","Constrain objective to this fraction of the optimal value" => 0.999},"SlowGeneKO-".$self->id().$self->selected_version()."-".$UniqueFilename.".log",undef,$self->selected_version()));
	} else {
		system($self->figmodel()->GenerateMFAToolkitCommandLineCall($UniqueFilename,$self->id(),$media,["ProductionMFA"],{"perform single KO experiments" => 1,"MFASolver" => "GLPK","Constrain objective to this fraction of the optimal value" => 0.1},"SlowGeneKO-".$self->id().$self->selected_version()."-".$UniqueFilename.".log",undef,$self->selected_version()));
	}	
	if (!-e $self->config("MFAToolkit output directory")->[0].$UniqueFilename."DeletionStudyResults.txt") {
		print "Deletion study file not found!.\n";
		return undef;	
	}
	my $deltbl = $self->figmodel()->database()->load_table($self->config("MFAToolkit output directory")->[0].$UniqueFilename."DeletionStudyResults.txt",";","|",1,["Experiment"]);
	for (my $i=0; $i < $deltbl->size(); $i++) {
		my $row = $deltbl->get_row($i);
		if ($row->{"Insilico growth"}->[0] < 0.0000001) {
			push(@{$output},$row->{Experiment}->[0]);	
		}
	}
	if (defined($output)) {
		if (defined($save) && $save == 1) {
			my $tbl = $self->essentials_table();
			my $row = $tbl->get_row_by_key($media,"MEDIA",1);
			$row->{"ESSENTIAL GENES"} = $output;
			$tbl->save();
		}
	}
	return $output;
}

=pod

=item * [string]:I<list of minimal genes> = B<run_gene_minimization> (string:I<media>,0/1:I<max growth>,0/1:I<save results>);

=cut

sub run_gene_minimization {
	my ($self,$media,$maxGrowth,$save) = @_;
	my $output;
	
	#Running the MFAToolkit
	my $UniqueFilename = $self->figmodel()->filename();
	if (defined($maxGrowth) && $maxGrowth == 1) {
		system($self->figmodel()->GenerateMFAToolkitCommandLineCall($UniqueFilename,$self->id(),$media,["ProductionMFA"],{"optimize organism genes" => 1,"MFASolver" => "CPLEX","Constrain objective to this fraction of the optimal value" => 0.999},"MinimizeGenes-".$self->id().$self->selected_version()."-".$UniqueFilename.".log",undef,$self->selected_version()));
	} else {
		system($self->figmodel()->GenerateMFAToolkitCommandLineCall($UniqueFilename,$self->id(),$media,["ProductionMFA"],{"optimize organism genes" => 1,"MFASolver" => "CPLEX","Constrain objective to this fraction of the optimal value" => 0.1},"MinimizeGenes-".$self->id().$self->selected_version()."-".$UniqueFilename.".log",undef,$self->selected_version()));
	}
	my $tbl = $self->figmodel()->LoadProblemReport($UniqueFilename);
	if (!defined($tbl)) {
		return undef;	
	}
	for (my $i=0; $i < $tbl->size(); $i++) {
		my $row = $tbl->get_row($i);
		if ($row->{Notes}->[0] =~ m/Recursive\sMILP\sGENE_USE\soptimization/) {
			my @array = split(/\|/,$row->{Notes}->[0]);
			my $solution = $array[0];
			$_ = $solution;
			my @OriginalArray = /(peg\.\d+)/g;
			push(@{$output},@OriginalArray);
			last;
		}	
	}
	
	if (defined($output)) {
		if (defined($save) && $save == 1) {
			my $tbl = $self->load_model_table("MinimalGenes");
			my $row = $tbl->get_table_by_key("MEDIA",$media)->get_row_by_key("MAXGROWTH",$maxGrowth);
			if (defined($row)) {
				$row->{GENES} = $output;
			} else {
				$tbl->add_row({GENES => $output,MEDIA => [$media],MAXGROWTH => [$maxGrowth]});
			}
			$tbl->save();
		}
	}
	return $output;
}

=pod

=item * [string]:I<list of inactive genes> = B<identify_inactive_genes> (string:I<media>,0/1:I<max growth>,0/1:I<save results>);

=cut

sub identify_inactive_genes {
	my ($self,$media,$maxGrowth,$save) = @_;
	my $output;
	#Running the MFAToolkit
	my $UniqueFilename = $self->figmodel()->filename();
	if (defined($maxGrowth) && $maxGrowth == 1) {
		system($self->figmodel()->GenerateMFAToolkitCommandLineCall($UniqueFilename,$self->id(),$media,["ProductionMFA"],{"find tight bounds" => 1,"MFASolver" => "GLPK","Constrain objective to this fraction of the optimal value" => 0.999},"Classify-".$self->id().$self->selected_version()."-".$UniqueFilename.".log",undef,$self->selected_version()));
	} else {
		system($self->figmodel()->GenerateMFAToolkitCommandLineCall($UniqueFilename,$self->id(),$media,["ProductionMFA"],{"find tight bounds" => 1,"MFASolver" => "GLPK","Constrain objective to this fraction of the optimal value" => 0.1},"Classify-".$self->id().$self->selected_version()."-".$UniqueFilename.".log",undef,$self->selected_version()));
	}
	#Reading in the output bounds file
	my $ReactionTB;
	if (-e $self->config("MFAToolkit output directory")->[0].$UniqueFilename."/MFAOutput/TightBoundsReactionData0.txt") {
		$ReactionTB = $self->figmodel()->database()->load_table($self->config("MFAToolkit output directory")->[0].$UniqueFilename."/MFAOutput/TightBoundsReactionData0.txt",";","|",1,["DATABASE ID"]);
	}
	if (!defined($ReactionTB)) {
		print STDERR "FIGMODEL:ClassifyModelReactions: Classification file not found when classifying reactions in ".$self->id().$self->selected_version()." with ".$media." media. Most likely the model did not grow.\n";
		return undef;
	}
	#Clearing output
	$self->figmodel()->clearing_output($UniqueFilename,"Classify-".$self->id().$self->selected_version()."-".$UniqueFilename.".log");
	my $geneHash;
	my $activeGeneHash;
	for (my $i=0; $i < $ReactionTB->size(); $i++) {
		my $Row = $ReactionTB->get_row($i);
		if (defined($Row->{"Min FLUX"}) && defined($Row->{"Max FLUX"}) && defined($Row->{"DATABASE ID"}) && $Row->{"DATABASE ID"}->[0] =~ m/rxn\d\d\d\d\d/) {
			my $data = $self->get_reaction_data($Row->{"DATABASE ID"}->[0]);
			if (defined($data->{"ASSOCIATED PEG"})) {
				my $active = 0;
				if ($Row->{"Min FLUX"}->[0] > 0.00000001 || $Row->{"Max FLUX"}->[0] < -0.00000001 || ($Row->{"Max FLUX"}->[0]-$Row->{"Min FLUX"}->[0]) > 0.00000001) {
					$active = 1;
				}	
				for (my $j=0; $j < @{$data->{"ASSOCIATED PEG"}}; $j++) {
					$_ = $data->{"ASSOCIATED PEG"}->[$j];
					my @OriginalArray = /(peg\.\d+)/g;
					for (my $k=0; $k < @OriginalArray; $k++) {
						if ($active == 1) {
							$activeGeneHash->{$OriginalArray[$k]} = 1;
						}
						$geneHash->{$OriginalArray[$k]} = 1;
					}
				}	
			}
		}
	}
	my @allGenes = keys(%{$geneHash});
	for (my $i=0; $i < @allGenes; $i++) {
		if (!defined($activeGeneHash->{$allGenes[$i]})) {
			push(@{$output},$allGenes[$i]);
		}
	}
	if (defined($output)) {
		if (defined($save) && $save == 1) {
			my $tbl = $self->load_model_table("InactiveGenes");
			my $row = $tbl->get_table_by_key("MEDIA",$media)->get_row_by_key("MAXGROWTH",$maxGrowth);
			if (defined($row)) {
				$row->{GENES} = $output;
			} else {
				$tbl->add_row({GENES => $output,MEDIA => [$media],MAXGROWTH => [$maxGrowth]});
			}
			$tbl->save();
		}
	}
	return $output;
}

sub ConvertVersionsToHistoryFile {
	my ($self) = @_;
	my $vone = 0;
	my $vtwo = 0;
	my $continue = 1;
	my $lastTable;
	my $currentTable;
	my $cause;
	my $lastChanged = 0;
	my $noHitCount = 0;
	while ($continue == 1) {
		$cause = "NONE";
		$currentTable = undef;
		if (-e $self->directory().$self->id()."V".($vone+1).".".$vtwo.".txt") {
			$noHitCount = 0;
			$lastChanged = 0;
			$vone = $vone+1;
			$currentTable = $self->figmodel()->database()->load_table($self->directory().$self->id()."V".$vone.".".$vtwo.".txt",";","|",1,["LOAD","DIRECTIONALITY","COMPARTMENT","ASSOCIATED PEG"]);	
			$cause = "RECONSTRUCTION";
		} elsif (-e $self->directory().$self->id()."V".$vone.".".($vtwo+1).".txt") {
			$noHitCount = 0;
			$lastChanged = 0;
			$vtwo = $vtwo+1;
			$currentTable = $self->figmodel()->database()->load_table($self->directory().$self->id()."V".$vone.".".$vtwo.".txt",";","|",1,["LOAD","DIRECTIONALITY","COMPARTMENT","ASSOCIATED PEG"]);	
			$cause = "AUTOCOMPLETION";
		} elsif ($lastChanged == 0) {
			$lastChanged = 1;
			$vone = $vone+1;
			$cause = "RECONSTRUCTION";
		} elsif ($lastChanged == 1) {
			$lastChanged = 2;
			$vone = $vone-1;
			$vtwo = $vtwo+1;
			$cause = "AUTOCOMPLETION";
		} elsif ($lastChanged == 2) {
			$lastChanged = 0;
			$vone = $vone+1;
			$cause = "RECONSTRUCTION";
		}
		if (defined($currentTable)) {
			if (defined($lastTable)) {
				print $cause."\t".$self->directory().$self->id()."V".$vone.".".$vtwo.".txt\n";
				$self->calculate_model_changes($lastTable,$cause,$currentTable,"V".$vone.".".$vtwo);
			}
			$lastTable = $currentTable;
		} else {
			$noHitCount++;
			if ($noHitCount >= 40) {
				last;
			}
		}
	}
}

=head2 Flux Balance Analysis Methods

=head3 fba
Definition:
	FIGMODELfba = FIGMODELmodel->fba();
Description:
	Returns a FIGMODELfba object for the specified model
=cut
sub fba {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{drnRxn => undef,geneKO => undef,rxnKO => undef,media => undef});
	return ModelSEED::FIGMODEL::FIGMODELfba->new({drnRxn => $args->{drnRxn}, figmodel => $self->figmodel(),model => $self->id(),geneKO => $args->{geneKO},rxnKO => $args->{rxnKO},media => $args->{media},parameter_files=>["ProductionMFA"]});
}

=head3 fbaDefaultStudies
Definition:
	{error => string} = FIGMODELmodel->fbaDefaultStudies({media => string:media ID});
Description:
=cut
sub fbaDefaultStudies {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{media => "Complete",singleKO => 1,classification => 1});
	if (defined($args->{error})) {return $self->error_message({function => "fbaDefaultStudies",args => $args});}
	#Calculating growth
	my $originalResults = $self->fbaCalculateGrowth($args);
	if (defined($originalResults->{error})) {return $self->error_message({message => $originalResults->{error},function => "fbaDefaultStudies",args => $args});}
	#Running FVA without growth to identify inactive reactions with no growth and with growth drains
	if ($args->{classification} == 1) {
		my $results = $self->fbaFVA($self->figmodel()->copyMergeHash([$args,{growth=>"none"}]));
		if (defined($results->{error})) {return $self->error_message({message => $results->{error},function => "fbaDefaultStudies",args => $args});}
		$results = $self->fbaFVA($self->figmodel()->copyMergeHash([$args,{growth=>"none",drnRxn => ["bio00001"]}]));
		if (defined($results->{error})) {return $self->error_message({message => $results->{error},function => "fbaDefaultStudies",args => $args});}
	}
	#Performing additional studies if growth occurs
	if ($originalResults->{growth} > 0) {
		if ($args->{singleKO} == 1) {
			$self->fbaComboDeletions($self->figmodel()->copyMergeHash([$args,{maxDeletions => 1}]));
		}
		if ($args->{classification} == 1) {
			$self->fbaFVA($args);
		}
	}
	return {};
}
=head3 fbaComboDeletions
Definition:
	{}:Output = FIGMODELmodel->fbaComboDeletions({
		maxDeletions => INTEGER:maximum number of deletions
	});
	Output = {
		essentialGenes => [string]:gene IDs,
		knockoutGrowth => {string:gene set => double:knockout viability},
		wildtype => double
	}
Description:
	Simulating knockout of genes in model
=cut
sub fbaComboDeletions {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{media => "Complete",maxDeletions=>1,saveKOResults=>1});
	if (defined($args->{error})) {return $self->error_message({function => "fbaComboDeletions",args => $args});}
	my $fbaObj = $self->fba($args);
	$fbaObj->setCombinatorialDeletionStudy($args);
	$fbaObj->runFBA();
	my $results = $fbaObj->parseCombinatorialDeletionStudy({});
	if (defined($args->{error})) {return $self->error_message({message => "Could not load combination KO results",function => "fbaComboDeletions",args => $args});}
	my $output = {wildtype => $results->{Wildtype}};
	foreach my $genes (keys(%{$results})) {
		if ($results->{$genes} < 0.000001) {
			if ($genes !~ m/;/ && $genes =~ m/peg/) {
				push(@{$output->{essentialGenes}},$genes);
			}
		}
		if ($genes =~ m/peg/) {
			$output->{knockoutGrowth}->{$genes} = $results->{$genes}/$output->{wildtype};
		}
	}
	if ($args->{saveKOResults} == 1) {
		my $tbl = $self->essentials_table();
		my $row = $tbl->get_row_by_key($self->{media},"MEDIA",1);
		$row->{"ESSENTIAL GENES"} = $output->{essentialGenes};
		$tbl->save();
		my $obj = $self->figmodel()->database()->get_object("mdless",{parameters => "NONE",MODEL => $self->id(),MEDIA => $args->{media}});
		if (!defined($obj)) {
			$obj = $self->figmodel()->database()->create_object("mdless",{parameters => "NONE",MODEL => $self->id(),MEDIA => $args->{media}});	
		}
		$obj->essentials(join(";",@{$output->{essentialGenes}}));
	}
	return $output;
}
=head3 fbaFVA
Definition:
	{}:Output = FIGMODELmodel->fbaFVA({
		
	});
Description:
	This function uses the MFAToolkit to minimize and maximize the flux through every reaction in the input model during minimal growth on the input media.
	The results are returned in a hash of strings where the keys are the reaction IDs and the strings are structured as follows: "Class;Min flux;Max flux".
	Possible values for "Class" include:
	1.) Positive: these reactions are essential in the forward direction.
	2.) Negative: these reactions are essential in the reverse direction.
	3.) Positive variable: these reactions are nonessential, but they only ever proceed in the forward direction.
	4.) Negative variable: these reactions are nonessential, but they only ever proceed in the reverse direction.
	5.) Variable: these reactions are nonessential and proceed in the forward or reverse direction.
	6.) Blocked: these reactions never carry any flux at all in the media condition tested.
	7.) Dead: these reactions are disconnected from the network.
=cut
sub fbaFVA {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{media=>"Complete",growth=>"forced",drnRxn=>[],saveFVAResults=>1,outputDirectory=>$self->figmodel()->config("database message file directory")->[0]});
	if (defined($args->{error})) {return $self->error_message({function => "fbaFVA",args => $args});}

	#Getting fba object
	my $fba = $self->fba($args);
	$fba->setTightBounds($args);
	$fba->runFBA();
	my $results = $fba->parseTightBounds();
	if (defined($results->{tb})) {
		my $rxnclasstable = $self->reaction_class_table();
		my $cpdclasstable = $self->compound_class_table();
		foreach my $obj (keys(%{$results->{tb}})) {
			my $row;
			if ($obj =~ m/(cpd\d\d\d\d\d)(.)/) {
				$row = $cpdclasstable->get_row_by_key($obj,"COMPOUND",1);
			} elsif ($obj =~ m/([rb][xi][no]\d\d\d\d\d)/) {
				$row = $rxnclasstable->get_row_by_key($1,"REACTION",1);
			}
			#Setting row values
			if (defined($row)) {
			    my $foundit = 0;
			    if (defined($row->{MEDIA})) {
				for (my $i=0; $i < @{$row->{MEDIA}};$i++) {
					if ($row->{MEDIA}->[$i] eq $args->{media}) {
					    $foundit = 1;
					    $row->{MIN}->[$i] = $results->{tb}->{$obj}->{min};
					    $row->{MAX}->[$i] = $results->{tb}->{$obj}->{max};
					    $row->{CLASS}->[$i] = $results->{tb}->{$obj}->{class};
					    $row->{MEDIA}->[$i] = $args->{media};
					    last;
					}
				}
			    }
			    if ($foundit == 0) {
				push @{$row->{MEDIA}}, $args->{media};
				push @{$row->{MIN}}, $results->{tb}->{$obj}->{min};
				push @{$row->{MAX}}, $results->{tb}->{$obj}->{max};
				push @{$row->{CLASS}}, $results->{tb}->{$obj}->{class};
			    }
			}
		}
		if ($args->{saveFVAResults} == 1) {
			my $parameters = "";
			if ($args->{growth} eq "forced") {
				$parameters .= "FG;";
				$rxnclasstable->save();
				$cpdclasstable->save();
			} elsif ($args->{growth} eq "none") {
				$parameters .= "NG;";
			}
			if (defined($args->{drnRxn})) {
				$parameters .= "DR:".join("|",@{$args->{drnRxn}}).";";
			}
			if (defined($args->{rxnKO})) {
				$parameters .= "RK:".join("|",@{$args->{rxnKO}}).";";
			}
			if (defined($args->{geneKO})) {
				$parameters .= "GK:".join("|",@{$args->{geneKO}}).";";
			}
			if (length($parameters) == 0) {
				$parameters = "NONE";	
			}
			#Loading and updating the PPO FVA table, which will ultimately replace the flatfile tables
			my $obj = $self->figmodel()->database()->get_object("mdlfva",{parameters => $parameters,MODEL => $self->id(),MEDIA => $args->{media}});
			if (!defined($obj)) {
				$obj = $self->figmodel()->database()->create_object("mdlfva",{parameters => $parameters,MODEL => $self->id(),MEDIA => $args->{media}});	
			}
			my $headings = ["inactive","dead","positive","negative","variable","posvar","negvar","positiveBounds","negativeBounds","variableBounds","posvarBounds","negvarBounds"];
			for (my $i=0; $i < @{$headings}; $i++) {
				my $function = $headings->[$i];
				$obj->$function($results->{$function});
			}
		}
	}	
	return $results;
}
=head3 fbaCalculateGrowth
Definition:
	{}:Output = FIGMODELmodel->fbaCalculateGrowth({
		growth => double,
		noGrowthCompounds => string:compound list	
	});
Description:
	Calculating growth in the input media
=cut
sub fbaCalculateGrowth {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{media => "Complete",parameters => {},saveLPfile => 1,filename => undef,outputDirectory => $self->figmodel()->config("database message file directory")->[0]});
	if (defined($args->{error})) {return $self->error_message({function => "fbaDefaultStudies",args => $args});}
	#Getting fba object
	my $fbaObj = $self->fba($args);
	$fbaObj->setSingleGrowthStudy();
	$fbaObj->set_parameters($args->{parameters});
	$fbaObj->runFBA();
	#Parsing results
	my $result = $fbaObj->parseSingleGrowthStudy();
	if (defined($result->{error})){return $self->error_message({message => $result->{error},function => "fbaCalculateGrowth",args => $args});}
	#Handling results
	$self->ppo()->growth($result->{growth});
	$self->ppo()->noGrowthCompounds($result->{noGrowthCompounds});
	if ($result->{growth} > 0.00000001 && -e $fbaObj->directory()."/MFAOutput/SolutionReactionData0.txt") {
		system("cp ".$fbaObj->directory()."/MFAOutput/SolutionReactionData0.txt ".$args->{outputDirectory}."Fluxes-".$self->id()."-".$args->{media}.".txt");
		system("cp ".$fbaObj->directory()."/MFAOutput/SolutionCompoundData0.txt ".$args->{outputDirectory}."CompoundFluxes-".$self->id()."-".$args->{media}.".txt");  
	}
	#Copying the LP file into the model directory
	if ($args->{saveLPfile} == 1 && -e $fbaObj->directory()."/CurrentProblem.lp") {
		system("cp ".$fbaObj->directory()."/CurrentProblem.lp ".$self->directory().$self->id().".lp");
	}
	$fbaObj->clearOutput();
	return $result;
}
=head3 fbaCalculateMinimalMedia
=item Definition:
	$results = FBAMODELmodel->fbaCalculateMinimalMedia($arguments);
	
	$arguments = {numFormulations => integer:number of formulations,
				  reactionKO => [string::reaction ids],
                  geneKO     => [string::gene ids]}
                  
	$results = {essentialNutrients => [string]:nutrient IDs,
				optionalNutrientSets => [[string]]:optional nutrient ID sets}
=item Description:
=cut
sub fbaCalculateMinimalMedia {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{numFormulations => 1,geneKO => [],rxnKO => []});
	my $fbaObj = ModelSEED::FIGMODEL::FIGMODELfba->new({figmodel => $self->figmodel(),geneKO=>$args->{geneKO},rxnKO=>$args->{rxnKO},model=>$self->id(),media=>"Complete",parameter_files=>["ProductionMFA"]});
	$fbaObj->setMinimalMediaStudy({numFormulations => $args->{numFormulations}});
	$fbaObj->runFBA();
	return $fbaObj->parseMinimalMediaStudy({filename => $fbaObj->filename()});
}

=head3 fbaSubmitGeneActivityAnalysis
=item Definition:
	$results = FIGMODELmodel->fbaSubmitGeneActivityAnalysis($arguments);
	$arguments = {media => opt string:media ID or "," delimited list of compounds,
				  geneCalls => {string:gene ID => double:call},
				  rxnKO => [string::reaction ids],
                  geneKO     => [string::gene ids]}
	$results = {jobid => integer:job ID}
=item Description:
=cut
sub fbaSubmitGeneActivityAnalysis {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["geneCalls"],{user => undef,password => undef});
	if (defined($args->{error})) {return {error => $args->{error}};}
	my $fbaObj = $self->fba();
	return $fbaObj->setGeneActivityAnalysis($args);
}
=head3 fbaMultiplePhenotypeStudy
Definition:
	{}:Output = FIGMODELmodel->fbaMultiplePhenotypeStudy({
		labels=>[string]:labels,
		mediaList=>[string]:media ID,
		KOlist=>[[string]]:reaction or gene ids,
		checkMetaboliteWhenZeroGrowth=>0/1
	});
	Output = {
		string:labels=>{
			label=>string:label,
			media=>string:media,
			rxnKO=>[string]:rxnKO,
			geneKO=>[string]:geneKO,
			wildType=>double:growth,
			growth=>double:growth,
			fraction=>double:fraction of growth,
			noGrowthCompounds=>[string]:no growth compound list,
			dependantReactions=>[string]:list of reactions inactivated by knockout
		}
	}
Description:
=cut
sub fbaMultiplePhenotypeStudy {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["mediaList","labels","KOlist"],{
		drnRxn=>undef,
		media=>"Complete",
		checkMetaboliteWhenZeroGrowth=>0,
		additionalParameters=>undef
	});
	if (defined($args->{error})) {return $self->error_message({function=>"fbaMultiplePhenotypeStudy",args=>$args});}
	my $fbaObj = $self->fba($args);
	$fbaObj->setMultiPhenotypeStudy($args);
	if (defined($args->{additionalParameters})) {
		$fbaObj->set_parameters($args->{additionalParameters});
	}
	if (defined($args->{drnRxn})) {
		$fbaObj->add_drain_reaction($args->{drnRxn});
	}
	$fbaObj->runFBA();
	my $result = $fbaObj->parseMultiPhenotypeStudy();
	$fbaObj->clearOutput();
	return $result;
}
=head3 fbaTestGapfillingSolution
Definition:
	{}:Output = FIGMODELmodel->fbaTestGapfillingSolution({
	});
Description:
=cut
sub fbaTestGapfillingSolution {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{media=>"Complete"});
	if (defined($args->{error})) {return $self->error_message({function=>"fbaTestGapfillingSolution",args=>$args});}
	my ($media,$label,$list);
	my $rxnTbl = $self->reaction_table(1);
	$rxnTbl->add_headings(("NOTES"));
	my $idhash;
	for (my $i=0; $i < $rxnTbl->size(); $i++) {
		my $row = $rxnTbl->get_row($i);
		if (defined($row->{"ASSOCIATED PEG"}) && $row->{"ASSOCIATED PEG"}->[0] =~ m/GAP|AUTOCOMPLETION/ ) {
			$idhash->{$row->{"LOAD"}->[0]} = $row;
			push(@{$media},"NONE");
			push(@{$list},[$row->{"LOAD"}->[0]]);
			push(@{$label},$row->{"LOAD"}->[0]);
		}
	}
	my $results = $self->fbaMultiplePhenotypeStudy({drnRxn=>["bio00001"],mediaList=>$media,labels=>$label,KOlist=>$list,checkMetaboliteWhenZeroGrowth=>1,additionalParameters=>{"find tight bounds" => 1,"delete noncontributing reactions" => 1}});	
	#Printing the results as notes in the model file
	my $deletionList;
	foreach my $lbl (keys(%{$results})) {
		if (defined($results->{$lbl}->{noGrowthCompounds}->[0]) && $results->{$lbl}->{noGrowthCompounds}->[0] ne "NA") {
			$idhash->{$lbl}->{"NOTES"}->[0] = "Required to produce:".join(",",@{$results->{$lbl}->{noGrowthCompounds}});
		}
		if (defined($results->{$lbl}->{dependantReactions}->[0]) && length($results->{$lbl}->{dependantReactions}->[0]) > 0) {
			if ($results->{$lbl}->{dependantReactions}->[0]	eq "DELETED") {
				$idhash->{$lbl}->{"NOTES"}->[0] = "DELETE";
			} else {
				$idhash->{$lbl}->{"NOTES"}->[0] = "Required to activate:".join(",",@{$results->{$lbl}->{dependantReactions}});
			}
		}
	}
	$rxnTbl->save();
	return $results;
	#Deleting reactions that were marked for deletion
	if (@{$deletionList} > 0) {
		$self->removeReactions({ids=>$deletionList,reason=>"Trimming autocompletion solution",trackChanges=>1});
	}
	return $results;
}
=head3 fbaBiomassPrecursorDependancy
Definition:
	{}:Output = FIGMODELmodel->fbaBiomassPrecursorDependancy({});
	Output = {
		string:labels=>{
			label=>string:label,
			media=>string:media,
			rxnKO=>[string]:rxnKO,
			geneKO=>[string]:geneKO,
			wildType=>double:growth,
			growth=>double:growth,
			fraction=>double:fraction of growth,
			noGrowthCompounds=>[string]:no growth compound list
		}
	}
Description:
=cut
sub fbaBiomassPrecursorDependancy {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{media=>$self->autocompleteMedia()});
	if (defined($args->{error})) {return $self->error_message({function=>"fbaBiomassPrecursorDependancy",args=>$args});}
	my ($media,$label,$list);
	my $rxnTbl = $self->reaction_table(1);
	$rxnTbl->add_headings(("NOTES"));
	my $idhash;
	for (my $i=0; $i < $rxnTbl->size(); $i++) {
		my $row = $rxnTbl->get_row($i);
		if (defined($row->{"ASSOCIATED PEG"}) && $row->{"ASSOCIATED PEG"}->[0] =~ m/GAP|AUTOCOMPLETION/ ) {
			$idhash->{$row->{"LOAD"}->[0]} = $row;
			push(@{$media},$args->{media});
			push(@{$list},[$row->{"LOAD"}->[0]]);
			push(@{$label},$row->{"LOAD"}->[0]);
		}
	}
	my $results = $self->fbaMultiplePhenotypeStudy({mediaList=>$media,labels=>$label,KOlist=>$list,checkMetaboliteWhenZeroGrowth=>1});	
	#Printing the results as notes in the model file
	foreach my $lbl (keys(%{$results})) {
		if (defined($results->{$lbl}->{noGrowthCompounds}->[0])) {
			$idhash->{$lbl}->{"NOTES"}->[0] = "Required to produce:".join(",",@{$results->{$lbl}->{noGrowthCompounds}});
		}
	}
	#Saving the model to file
	$rxnTbl->save();
	return {};
}

=head2 Database Integration Methods
=head3 generateBaseModelFileFromDatabase
=item Definition:
    [0:1] = FIGMODELmodel->generateBaseModelFileFromDatabase();
=item Description:
    This function attempts to generate the base model file, $self->directory().$self->id().".txt",
    that is needed to run processModel. Basically if the model is listed in the MODEL table, this
    pulls all items out of the REACTION_MODEL table that correspond to that model. 
=cut
    
sub generateBaseModelFileFromDatabase {
    my ($self) = @_;
    if (!-d $self->directory()) {
        mkdir $self->directory();
    }
    my $baseModelFile = $self->directory() . $self->id() . ".txt";
    my $db = $self->figmodel()->database();
    # Confirm that the model exists in the MODEL table
    my $modelRows = $db->get_objects('model', {'id' => $self->id()});
    if(defined($modelRows) && @$modelRows != 1) {
        return $self->figmodel()->fail();
    }
    # Now get all the reactions associated with the model
    my $modelRxns = $db->get_objects('rxnmdl', {'MODEL' => $self->id()});
    if(@$modelRxns == 0) {
        return $self->figmodel()->fail();
    }
    # Construct the table
    my $table = [];
    push(@$table, ["REACTIONS"]); 
    push(@$table, ["LOAD", "DIRECTIONALITY", "COMPARTMENT", "ASSOCIATED PEG",
                  "SUBSYSTEM", "CONFIDENCE", "REFERENCE", "NOTES"]);
    for(my $i=0; $i<@$modelRxns; $i++) {
        my $rxnmdl = $modelRxns->[$i];
        next unless(defined($rxnmdl));
        my $subsystems = [];
        my $pegs = $rxnmdl->pegs();
        if(defined($pegs) && $pegs =~ /(peg\.\d+)/) {
            while ($pegs =~ /(peg\.\d+)/ ) {
                
            }
        }
        if (@$subsystems == 0) {
            push(@$subsystems, "NONE");
        }
        my $row = [ $rxnmdl->REACTION(), $rxnmdl->directionality(), $rxnmdl->compartment(),
             $rxnmdl->pegs(), join('|',@$subsystems), $rxnmdl->confidence(), "NONE", "NONE"];
        push(@$table, $row);
    }
    open ( my $modelFH, ">", $baseModelFile);
    foreach my $row (@$table) {
        print $modelFH join(';', @$row) . "\n";
    }
    close($modelFH);
    return $self->figmodel()->success();
}

=head3 check_for_role_changes
Definition:
	{changed=>{string:mapped role=>{string:gene role=>{string:reaction=>{string:gene=>1}}}},new=>{string:role=>{string:reaction=>{string:gene=>1}}}}
	= FIGMODELmodel->check_for_role_changes(
	{changed=>{string:mapped role=>{string:gene role=>{string:reaction=>{string:gene=>1}}}},new=>{string:role=>{string:reaction=>{string:gene=>1}}}});
=cut

sub check_for_role_changes {
	my ($self,$roleChangeHash,$roleGeneHash) = @_;
	#Getting reaction table
	my $ftrTbl = $self->feature_table();
	if (defined($ftrTbl)) {
		for (my $i=0; $i < $ftrTbl->size(); $i++) {
			my $row = $ftrTbl->get_row($i);
			my $rxnHash;
			for (my $j=0; $j < @{$row->{ROLES}}; $j++) {
				$roleGeneHash->{$row->{ROLES}->[$j]}->{$row->{ID}->[0]} = 1;
				my $rxns = $self->figmodel()->mapping()->get_role_rxns($row->{ROLES}->[$j]);
				if (defined($rxns)) {
					for (my $k=0; $k < @{$rxns}; $k++) {
						$rxnHash->{$rxns->[$k]} = 1;
					}
				}
			}
			#Checking if new reactions will appear
			my @rxnKeys = keys(%{$rxnHash});
			for (my $k=0; $k < @rxnKeys; $k++) {
				my $match = 0;
				for (my $j=0; $j < @{$row->{$self->id()."REACTIONS"}}; $j++) {
					if ($rxnKeys[$k] eq $row->{$self->id()."REACTIONS"}->[$j]) {
						$match = 1;
						last;	
					}
				}
				if ($match == 0) {
					my $roles = $self->figmodel()->mapping()->get_rxn_roles($rxnKeys[$k]);
					if (defined($roles)) {
						for (my $j=0; $j < @{$roles}; $j++) {
							for (my $m=0; $m < @{$row->{ROLES}}; $m++) {
								if ($roles->[$j] eq $row->{ROLES}->[$m]) {
									$roleChangeHash->{new}->{$roles->[$j]}->{reactions}->{$rxnKeys[$k]} = 1;
									$roleChangeHash->{new}->{$roles->[$j]}->{genes}->{$row->{ID}->[0]} = 1;
									last;
								}
							}
						}
					}
				}
			}
			#Checking if the gene is mapped to reactions that it should not be mapped to (according to current mappings)
			for (my $j=0; $j < @{$row->{$self->id()."REACTIONS"}}; $j++) {
				my $match = 0;
				my @rxnKeys = keys(%{$rxnHash});
				for (my $k=0; $k < @rxnKeys; $k++) {
					if ($rxnKeys[$k] eq $row->{$self->id()."REACTIONS"}->[$j]) {
						$match = 1;
						last;	
					}
				}
				if ($match == 0) {
					my $roles = $self->figmodel()->mapping()->get_rxn_roles($row->{$self->id()."REACTIONS"}->[$j]);
					if (defined($roles)) {
						for (my $k=0; $k < @{$roles}; $k++) {
							for (my $m=0; $m < @{$row->{ROLES}}; $m++) {
								$roleChangeHash->{changed}->{$roles->[$k]}->{$row->{ROLES}->[$m]}->{reactions}->{$row->{$self->id()."REACTIONS"}->[$j]} = 1;
								$roleChangeHash->{changed}->{$roles->[$k]}->{$row->{ROLES}->[$m]}->{genes}->{$row->{ID}->[0]} = 1;
							}
						}
					}
				}
			}
		}
	}
	return ($roleChangeHash,$roleGeneHash);
}
=head3 run_default_model_predictions
REPLACED BY fbaDefaultStudies:MARKED FOR DELETION
=cut
sub run_default_model_predictions {
	my ($self,$Media) = @_;
	my $out = $self->fbaDefaultStudies({media => $Media});
	return $self->figmodel()->success();
}
=head3 calculate_growth
REPLACED BY fbaCalculateGrowth:MARKED FOR DELETION
=cut
sub calculate_growth {
	my ($self,$Media,$outputDirectory,$InParameters,$saveLPFile) = @_;
	my $result = $self->fbaCalculateGrowth({media => $Media,outputDirectory => $outputDirectory,parameters => $InParameters,saveLPfile => $saveLPFile});
	if (defined($result->{growth}) && $result->{growth} > 0) {
		return $result->{growth};
	} else {
		return "NOGROWTH:".$result->{noGrowthCompounds};
	}
	return "";
}
=head3 classify_model_reactions
REPLACED BY fbaFVA:MARKED FOR DELETION
=cut
sub classify_model_reactions {
	my ($self,$Media,$SaveChanges,$forcingGrowth) = @_;
	my $result = $self->fbaFVA({media=>$Media,saveFVAResults=>$SaveChanges,forceGrowth=>$forcingGrowth});
	if (defined($result->{error})) {return $self->error_message({message => $result->{error},function => "fbaDefaultStudies",args => {}});}
	return ($self->reaction_class_table(),$self->compound_class_table());
}
=head3 IdentifyDependancyOfGapFillingReactions
REPLACED BY fbaBiomassPrecursorDependancy:MARKED FOR DELETION
=cut
sub IdentifyDependancyOfGapFillingReactions {
	my ($self,$media) = @_;
	return $self->fbaBiomassPrecursorDependancy({media=>$media});
}
=head3 remove_reaction
REPLACED BY removeReactions:MARKED FOR DELETION (new function conforms with our new coding style and allows simultaneous deletion of multiple reactions)
=cut
sub remove_reaction {
    my ($self, $rxnId, $compartment) = @_;
    my $result = $self->removeReactions({ids=>[$rxnId],compartments=>[$compartment],reason=>"Model controls",user=>$self->owner(),trackChanges=>1});
    if (defined($result->{error})) {
    	$self->error_message($result->{error});
    	return $self->figmodel()->fail();
    }
    return $self->figmodel()->success();
}

1;