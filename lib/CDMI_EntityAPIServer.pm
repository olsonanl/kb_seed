package CDMI_EntityAPIServer;

use Data::Dumper;
use Moose;
use KBRpcContext;

extends 'RPC::Any::Server::JSONRPC::PSGI';

has 'instance_dispatch' => (is => 'ro', isa => 'HashRef');
has 'user_auth' => (is => 'ro', isa => 'UserAuth');
has 'valid_methods' => (is => 'ro', isa => 'HashRef', lazy => 1,
			builder => '_build_valid_methods');

our $CallContext;

sub _build_valid_methods
{
    my($self) = @_;
    my $methods = {
        'get_entity_AlignmentTree' => 1,
        'all_entities_AlignmentTree' => 1,
        'get_entity_Annotation' => 1,
        'all_entities_Annotation' => 1,
        'get_entity_AtomicRegulon' => 1,
        'all_entities_AtomicRegulon' => 1,
        'get_entity_Attribute' => 1,
        'all_entities_Attribute' => 1,
        'get_entity_Biomass' => 1,
        'all_entities_Biomass' => 1,
        'get_entity_BiomassCompound' => 1,
        'all_entities_BiomassCompound' => 1,
        'get_entity_Compartment' => 1,
        'all_entities_Compartment' => 1,
        'get_entity_Complex' => 1,
        'all_entities_Complex' => 1,
        'get_entity_Compound' => 1,
        'all_entities_Compound' => 1,
        'get_entity_Contig' => 1,
        'all_entities_Contig' => 1,
        'get_entity_ContigChunk' => 1,
        'all_entities_ContigChunk' => 1,
        'get_entity_ContigSequence' => 1,
        'all_entities_ContigSequence' => 1,
        'get_entity_CoregulatedSet' => 1,
        'all_entities_CoregulatedSet' => 1,
        'get_entity_Diagram' => 1,
        'all_entities_Diagram' => 1,
        'get_entity_EcNumber' => 1,
        'all_entities_EcNumber' => 1,
        'get_entity_Experiment' => 1,
        'all_entities_Experiment' => 1,
        'get_entity_Family' => 1,
        'all_entities_Family' => 1,
        'get_entity_Feature' => 1,
        'all_entities_Feature' => 1,
        'get_entity_Genome' => 1,
        'all_entities_Genome' => 1,
        'get_entity_Identifier' => 1,
        'all_entities_Identifier' => 1,
        'get_entity_Media' => 1,
        'all_entities_Media' => 1,
        'get_entity_Model' => 1,
        'all_entities_Model' => 1,
        'get_entity_ModelCompartment' => 1,
        'all_entities_ModelCompartment' => 1,
        'get_entity_OTU' => 1,
        'all_entities_OTU' => 1,
        'get_entity_PairSet' => 1,
        'all_entities_PairSet' => 1,
        'get_entity_Pairing' => 1,
        'all_entities_Pairing' => 1,
        'get_entity_ProbeSet' => 1,
        'all_entities_ProbeSet' => 1,
        'get_entity_ProteinSequence' => 1,
        'all_entities_ProteinSequence' => 1,
        'get_entity_Publication' => 1,
        'all_entities_Publication' => 1,
        'get_entity_Reaction' => 1,
        'all_entities_Reaction' => 1,
        'get_entity_ReactionRule' => 1,
        'all_entities_ReactionRule' => 1,
        'get_entity_Reagent' => 1,
        'all_entities_Reagent' => 1,
        'get_entity_Requirement' => 1,
        'all_entities_Requirement' => 1,
        'get_entity_Role' => 1,
        'all_entities_Role' => 1,
        'get_entity_SSCell' => 1,
        'all_entities_SSCell' => 1,
        'get_entity_SSRow' => 1,
        'all_entities_SSRow' => 1,
        'get_entity_Scenario' => 1,
        'all_entities_Scenario' => 1,
        'get_entity_Source' => 1,
        'all_entities_Source' => 1,
        'get_entity_Subsystem' => 1,
        'all_entities_Subsystem' => 1,
        'get_entity_SubsystemClass' => 1,
        'all_entities_SubsystemClass' => 1,
        'get_entity_TaxonomicGrouping' => 1,
        'all_entities_TaxonomicGrouping' => 1,
        'get_entity_Variant' => 1,
        'all_entities_Variant' => 1,
        'get_entity_Variation' => 1,
        'all_entities_Variation' => 1,
        'get_relationship_AffectsLevelOf' => 1,
        'get_relationship_IsAffectedIn' => 1,
        'get_relationship_Aligns' => 1,
        'get_relationship_IsAlignedBy' => 1,
        'get_relationship_Concerns' => 1,
        'get_relationship_IsATopicOf' => 1,
        'get_relationship_Contains' => 1,
        'get_relationship_IsContainedIn' => 1,
        'get_relationship_Describes' => 1,
        'get_relationship_IsDescribedBy' => 1,
        'get_relationship_Displays' => 1,
        'get_relationship_IsDisplayedOn' => 1,
        'get_relationship_Encompasses' => 1,
        'get_relationship_IsEncompassedIn' => 1,
        'get_relationship_GeneratedLevelsFor' => 1,
        'get_relationship_WasGeneratedFrom' => 1,
        'get_relationship_HasAssertionFrom' => 1,
        'get_relationship_Asserts' => 1,
        'get_relationship_HasCompoundAliasFrom' => 1,
        'get_relationship_UsesAliasForCompound' => 1,
        'get_relationship_HasIndicatedSignalFrom' => 1,
        'get_relationship_IndicatesSignalFor' => 1,
        'get_relationship_HasMember' => 1,
        'get_relationship_IsMemberOf' => 1,
        'get_relationship_HasParticipant' => 1,
        'get_relationship_ParticipatesIn' => 1,
        'get_relationship_HasPresenceOf' => 1,
        'get_relationship_IsPresentIn' => 1,
        'get_relationship_HasReactionAliasFrom' => 1,
        'get_relationship_UsesAliasForReaction' => 1,
        'get_relationship_HasRepresentativeOf' => 1,
        'get_relationship_IsRepresentedIn' => 1,
        'get_relationship_HasResultsIn' => 1,
        'get_relationship_HasResultsFor' => 1,
        'get_relationship_HasSection' => 1,
        'get_relationship_IsSectionOf' => 1,
        'get_relationship_HasStep' => 1,
        'get_relationship_IsStepOf' => 1,
        'get_relationship_HasUsage' => 1,
        'get_relationship_IsUsageOf' => 1,
        'get_relationship_HasValueFor' => 1,
        'get_relationship_HasValueIn' => 1,
        'get_relationship_Includes' => 1,
        'get_relationship_IsIncludedIn' => 1,
        'get_relationship_IndicatedLevelsFor' => 1,
        'get_relationship_HasLevelsFrom' => 1,
        'get_relationship_Involves' => 1,
        'get_relationship_IsInvolvedIn' => 1,
        'get_relationship_IsARequirementIn' => 1,
        'get_relationship_IsARequirementOf' => 1,
        'get_relationship_IsAlignedIn' => 1,
        'get_relationship_IsAlignmentFor' => 1,
        'get_relationship_IsAnnotatedBy' => 1,
        'get_relationship_Annotates' => 1,
        'get_relationship_IsBindingSiteFor' => 1,
        'get_relationship_IsBoundBy' => 1,
        'get_relationship_IsClassFor' => 1,
        'get_relationship_IsInClass' => 1,
        'get_relationship_IsCollectionOf' => 1,
        'get_relationship_IsCollectedInto' => 1,
        'get_relationship_IsComposedOf' => 1,
        'get_relationship_IsComponentOf' => 1,
        'get_relationship_IsComprisedOf' => 1,
        'get_relationship_Comprises' => 1,
        'get_relationship_IsConfiguredBy' => 1,
        'get_relationship_ReflectsStateOf' => 1,
        'get_relationship_IsConsistentWith' => 1,
        'get_relationship_IsConsistentTo' => 1,
        'get_relationship_IsControlledUsing' => 1,
        'get_relationship_Controls' => 1,
        'get_relationship_IsCoregulatedWith' => 1,
        'get_relationship_HasCoregulationWith' => 1,
        'get_relationship_IsCoupledTo' => 1,
        'get_relationship_IsCoupledWith' => 1,
        'get_relationship_IsDefaultFor' => 1,
        'get_relationship_RunsByDefaultIn' => 1,
        'get_relationship_IsDefaultLocationOf' => 1,
        'get_relationship_HasDefaultLocation' => 1,
        'get_relationship_IsDeterminedBy' => 1,
        'get_relationship_Determines' => 1,
        'get_relationship_IsDividedInto' => 1,
        'get_relationship_IsDivisionOf' => 1,
        'get_relationship_IsExemplarOf' => 1,
        'get_relationship_HasAsExemplar' => 1,
        'get_relationship_IsFamilyFor' => 1,
        'get_relationship_DeterminesFunctionOf' => 1,
        'get_relationship_IsFormedOf' => 1,
        'get_relationship_IsFormedInto' => 1,
        'get_relationship_IsFunctionalIn' => 1,
        'get_relationship_HasFunctional' => 1,
        'get_relationship_IsGroupFor' => 1,
        'get_relationship_IsInGroup' => 1,
        'get_relationship_IsImplementedBy' => 1,
        'get_relationship_Implements' => 1,
        'get_relationship_IsInPair' => 1,
        'get_relationship_IsPairOf' => 1,
        'get_relationship_IsInstantiatedBy' => 1,
        'get_relationship_IsInstanceOf' => 1,
        'get_relationship_IsLocatedIn' => 1,
        'get_relationship_IsLocusFor' => 1,
        'get_relationship_IsModeledBy' => 1,
        'get_relationship_Models' => 1,
        'get_relationship_IsNamedBy' => 1,
        'get_relationship_Names' => 1,
        'get_relationship_IsOwnerOf' => 1,
        'get_relationship_IsOwnedBy' => 1,
        'get_relationship_IsProposedLocationOf' => 1,
        'get_relationship_HasProposedLocationIn' => 1,
        'get_relationship_IsProteinFor' => 1,
        'get_relationship_Produces' => 1,
        'get_relationship_IsRealLocationOf' => 1,
        'get_relationship_HasRealLocationIn' => 1,
        'get_relationship_IsRegulatedIn' => 1,
        'get_relationship_IsRegulatedSetOf' => 1,
        'get_relationship_IsRelevantFor' => 1,
        'get_relationship_IsRelevantTo' => 1,
        'get_relationship_IsRequiredBy' => 1,
        'get_relationship_Requires' => 1,
        'get_relationship_IsRoleOf' => 1,
        'get_relationship_HasRole' => 1,
        'get_relationship_IsRowOf' => 1,
        'get_relationship_IsRoleFor' => 1,
        'get_relationship_IsSequenceOf' => 1,
        'get_relationship_HasAsSequence' => 1,
        'get_relationship_IsSubInstanceOf' => 1,
        'get_relationship_Validates' => 1,
        'get_relationship_IsSuperclassOf' => 1,
        'get_relationship_IsSubclassOf' => 1,
        'get_relationship_IsTargetOf' => 1,
        'get_relationship_Targets' => 1,
        'get_relationship_IsTaxonomyOf' => 1,
        'get_relationship_IsInTaxa' => 1,
        'get_relationship_IsTerminusFor' => 1,
        'get_relationship_HasAsTerminus' => 1,
        'get_relationship_IsTriggeredBy' => 1,
        'get_relationship_Triggers' => 1,
        'get_relationship_IsUsedAs' => 1,
        'get_relationship_IsUseOf' => 1,
        'get_relationship_Manages' => 1,
        'get_relationship_IsManagedBy' => 1,
        'get_relationship_OperatesIn' => 1,
        'get_relationship_IsUtilizedIn' => 1,
        'get_relationship_Overlaps' => 1,
        'get_relationship_IncludesPartOf' => 1,
        'get_relationship_ParticipatesAs' => 1,
        'get_relationship_IsParticipationOf' => 1,
        'get_relationship_ProducedResultsFor' => 1,
        'get_relationship_HadResultsProducedBy' => 1,
        'get_relationship_ProjectsOnto' => 1,
        'get_relationship_IsProjectedOnto' => 1,
        'get_relationship_Provided' => 1,
        'get_relationship_WasProvidedBy' => 1,
        'get_relationship_Shows' => 1,
        'get_relationship_IsShownOn' => 1,
        'get_relationship_Submitted' => 1,
        'get_relationship_WasSubmittedBy' => 1,
        'get_relationship_Uses' => 1,
        'get_relationship_IsUsedBy' => 1,
    };
    return $methods;
}

sub call_method {
    my ($self, $data, $method_info) = @_;
    my ($module, $method) = @$method_info{qw(module method)};
    
    my $ctx = KBRpcContext->new(client_ip => $self->_plack_req->address);
    
    my $args = $data->{arguments};
    if (@$args == 1 && ref($args->[0]) eq 'HASH')
    {
	my $actual_args = $args->[0]->{args};
	my $token = $args->[0]->{auth_token};
	$data->{arguments} = $actual_args;
	
	
        # Service CDMI_EntityAPI does not require authentication.
	
    }
    
    my $new_isa = $self->get_package_isa($module);
    no strict 'refs';
    local @{"${module}::ISA"} = @$new_isa;
    local $CallContext = $ctx;
    my @result = $module->$method(@{ $data->{arguments} });
    return \@result;
}


sub get_method
{
    my ($self, $data) = @_;
    
    my $full_name = $data->{method};
    
    $full_name =~ /^(\S+)\.([^\.]+)$/;
    my ($package, $method) = ($1, $2);
    
    if (!$package || !$method) {
	$self->exception('NoSuchMethod',
			 "'$full_name' is not a valid method. It must"
			 . " contain a package name, followed by a period,"
			 . " followed by a method name.");
    }

    if (!$self->valid_methods->{$method})
    {
	$self->exception('NoSuchMethod',
			 "'$method' is not a valid method in service CDMI_EntityAPI.");
    }
	
    my $inst = $self->instance_dispatch->{$package};
    my $module;
    if ($inst)
    {
	$module = $inst;
    }
    else
    {
	$module = $self->get_module($package);
	if (!$module) {
	    $self->exception('NoSuchMethod',
			     "There is no method package named '$package'.");
	}
	
	Class::MOP::load_class($module);
    }
    
    if (!$module->can($method)) {
	$self->exception('NoSuchMethod',
			 "There is no method named '$method' in the"
			 . " '$package' package.");
    }
    
    return { module => $module, method => $method };
}

1;
