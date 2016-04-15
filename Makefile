TOP_DIR = ../..
include $(TOP_DIR)/tools/Makefile.common

DEPLOY_RUNTIME ?= /kb/runtime
TARGET ?= /kb/deployment

ifeq ($(RASTTK_DEPLOYMENT),)

SRC_PERL = $(wildcard scripts/*.pl)
BIN_PERL = $(addprefix $(BIN_DIR)/,$(basename $(notdir $(SRC_PERL))))
DEPLOY_PERL = $(addprefix $(TARGET)/bin/,$(basename $(notdir $(SRC_PERL))))

SRC_SERVICE_PERL = $(wildcard service-scripts/*.pl)
BIN_SERVICE_PERL = $(addprefix $(BIN_DIR)/,$(basename $(notdir $(SRC_SERVICE_PERL))))
DEPLOY_SERVICE_PERL = $(addprefix $(SERVICE_DIR)/bin/,$(basename $(notdir $(SRC_SERVICE_PERL))))

else

std_SRC_PERL = $(wildcard scripts/*.pl)
std_BIN_PERL = $(addprefix $(BIN_DIR)/,$(basename $(notdir $(std_SRC_PERL))))
std_DEPLOY_PERL = $(addprefix $(TARGET)/bin/,$(basename $(notdir $(std_SRC_PERL))))

std_SRC_SERVICE_PERL = $(wildcard service-scripts/*.pl)
std_BIN_SERVICE_PERL = $(addprefix $(BIN_DIR)/,$(basename $(notdir $(std_SRC_SERVICE_PERL))))
std_DEPLOY_SERVICE_PERL = $(addprefix $(TARGET)/bin/,$(basename $(notdir $(std_SRC_SERVICE_PERL))))

SRC_PERL = $(std_SRC_PERL) $(std_SRC_SERVICE_PERL)
BIN_PERL = $(std_BIN_PERL) $(std_BIN_SERVICE_PERL)
DEPLOY_PERL = $(std_DEPLOY_PERL) $(std_DEPLOY_SERVICE_PERL)

endif

SERVER_MODULE = CDMI_API
SERVICE = cdmi_api
SERVICE_NAME = CDMI
SERVICE_NAME_PY = cdmi
SERVICE_PSGI_FILE = $(SERVICE_NAME).psgi
SERVICE_PORT = 7032

SERVICE_URL = http://kbase.us/services/$(SERVICE)
#SERVICE_URL = http://10.0.16.68:$(SERVICE_PORT)

CLIENT_TESTS = $(wildcard t/client-tests/*.t)
SERVER_TESTS = $(wildcard t/server-tests/*.t)
PROD_TESTS = $(wildcard t/prod-tests/*.t)

SPHINX_PORT = 7038
SPHINX_HOST = localhost

STARMAN_WORKERS = 8
STARMAN_MAX_REQUESTS = 100

TPAGE_ARGS = --define kb_top=$(TARGET) --define kb_runtime=$(DEPLOY_RUNTIME) --define kb_service_name=$(SERVICE) \
	--define kb_service_port=$(SERVICE_PORT) --define kb_service_dir=$(SERVICE_DIR) \
	--define kb_sphinx_port=$(SPHINX_PORT) --define kb_sphinx_host=$(SPHINX_HOST) \
	--define kb_starman_workers=$(STARMAN_WORKERS) \
	--define kb_starman_max_requests=$(STARMAN_MAX_REQUESTS)

JARFILE = $(PWD)/dist/lib/cdmi.jar

all: bin compile-typespec
#all: bin jar

SAPLING_XML = lib/KSaplingDBD.xml

bin: $(BIN_PERL) $(BIN_SERVICE_PERL)

build-erdb: lib/Bio/KBase/CDMI/CDMI_EntityAPIImpl.pm lib/CDMI-EntityAPI.spec

lib/CDMI-EntityAPI.spec lib/Bio/KBase/CDMI/CDMI_EntityAPIImpl.pm: $(SAPLING_XML)
	compile_dbd_to_typespec CDMI_API CDMI_EntityAPI $(SAPLING_XML) CDMI-EntityAPI.spec  \
		lib/Bio/KBase/CDMI/CDMI_EntityAPIImpl.pm scripts
	mv CDMI-EntityAPI.spec lib/CDMI-EntityAPI.spec

jar: 
	ant -Djar_file=$(JARFILE) -Dkb_top=$(KB_TOP) dist

deploy: deploy-all
deploy-all: deploy-client deploy-service
deploy-client: compile-typespec deploy-libs deploy-scripts deploy-docs

deploy-service: deploy-dir deploy-monit deploy-sphinx deploy-service-scripts
	$(TPAGE) $(TPAGE_ARGS) service/start_service.tt > $(TARGET)/services/$(SERVICE)/start_service
	chmod +x $(TARGET)/services/$(SERVICE)/start_service
	$(TPAGE) $(TPAGE_ARGS) service/stop_service.tt > $(TARGET)/services/$(SERVICE)/stop_service
	chmod +x $(TARGET)/services/$(SERVICE)/stop_service

deploy-service-scripts:
	export KB_TOP=$(TARGET); \
	export KB_RUNTIME=$(DEPLOY_RUNTIME); \
	export KB_PERL_PATH=$(TARGET)/lib ; \
	for src in $(SRC_SERVICE_PERL) ; do \
	        basefile=`basename $$src`; \
	        base=`basename $$src .pl`; \
	        echo install $$src $$base ; \
	        cp $$src $(TARGET)/plbin ; \
	        $(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/$$basefile" $(TARGET)/services/$(SERVICE)/bin/$$base ; \
	done


deploy-dir:
	if [ ! -d $(SERVICE_DIR) ] ; then mkdir $(SERVICE_DIR) ; fi
	if [ ! -d $(SERVICE_DIR)/webroot ] ; then mkdir $(SERVICE_DIR)/webroot ; fi
	if [ ! -d $(SERVICE_DIR)/bin ] ; then mkdir $(SERVICE_DIR)/bin ; fi
	if [ ! -d $(SERVICE_DIR)/sphinx ] ; then mkdir $(SERVICE_DIR)/sphinx ; fi

deploy-sphinx:
	$(TPAGE) $(TPAGE_ARGS) service/reindex_sphinx.tt > $(TARGET)/services/$(SERVICE)/reindex_sphinx
	chmod +x $(TARGET)/services/$(SERVICE)/reindex_sphinx
	$(TPAGE) $(TPAGE_ARGS) service/start_sphinx.tt > $(TARGET)/services/$(SERVICE)/start_sphinx
	chmod +x $(TARGET)/services/$(SERVICE)/start_sphinx
	$(TPAGE) $(TPAGE_ARGS) service/stop_sphinx.tt > $(TARGET)/services/$(SERVICE)/stop_sphinx
	chmod +x $(TARGET)/services/$(SERVICE)/stop_sphinx
	$(DEPLOY_RUNTIME)/bin/perl service-scripts/gen_cdmi_sphinx_conf.pl $(SAPLING_XML) lib/sphinx.conf.tt $(TPAGE_ARGS) > $(TARGET)/services/$(SERVICE)/sphinx.conf

deploy-monit:
	$(TPAGE) $(TPAGE_ARGS) service/process.$(SERVICE).tt > $(TARGET)/services/$(SERVICE)/process.$(SERVICE)

deploy-docs: deploy-dir
	$(DEPLOY_RUNTIME)/bin/pod2html -t "Central Store Application API" lib/Bio/KBase/CDMI/CDMI_APIImpl.pm > doc/application_api.html
	$(DEPLOY_RUNTIME)/bin/pod2html -t "Central Store Entity/Relationship API" lib/Bio/KBase/CDMI/CDMI_EntityAPIImpl.pm > doc/er_api.html
	cp doc/*html $(SERVICE_DIR)/webroot/.

compile-typespec: Makefile
	mkdir -p lib/biokbase/$(SERVICE_NAME_PY)
	touch lib/biokbase/__init__.py #do not include code in biokbase/__init__.py
	touch lib/biokbase/$(SERVICE_NAME_PY)/__init__.py 
	mkdir -p lib/javascript/$(SERVICE_NAME)
		#-psgi $(SERVICE_PSGI_FILE) \ #psgi compilation for the cdmi_api doesn't work quite right at the moment, just use the old one
	compile_typespec \
		--impl Bio::KBase::$(SERVICE_NAME)::%sImpl \
		--service Bio::KBase::$(SERVICE_NAME)::Service \
		--client Bio::KBase::$(SERVICE_NAME)::Client \
		--py biokbase/$(SERVICE_NAME_PY)/client \
		--js javascript/$(SERVICE_NAME)/Client \
		--url $(SERVICE_URL) \
		lib/$(SERVICE_NAME)-API.spec lib/$(SERVICE_NAME)-EntityAPI.spec lib
	-rm -r lib/$(SERVER_MODULE)Server.py
	-rm -r lib/$(SERVER_MODULE)Impl.py
	-rm -r lib/CDMI_EntityAPIImpl.py

java-client: java.out/built_flag

java.out/built_flag: lib/CDMI-API.spec lib/CDMI-EntityAPI.spec 
	rm -rf java.out
	mkdir java.out
	gen_java_client lib/CDMI-API.spec lib/CDMI-EntityAPI.spec us.kbase.CDMI_API java.out
	#
	# Ugh. Until we fix the XML or the compiler, patch the subsystem class to remove the reserved word
	#
	perl -pi.bak -e 's/private/m_private/' java.out/us/kbase/CDMI_API/fields_Subsystem.java
	cd java.out; find us -type f -name \*.java -print > tmp.files
	cd java.out; $(JAVAC) $(JAVAC_FLAGS) @tmp.files
	cd java.out; find us -type f -name \*.class -print > tmp.files
	cd java.out; $(JAR) cf cdmi.jar @tmp.files
	touch java.out/built_flag

test: test-client
	echo "running client and script tests"

# What does it mean to test a client. This is a test of a client
# library. If it is a client-server module, then it should be
# run against a running server. You can say that this also tests
# the server, and I agree. You can add a test-server dependancy
# to the test-client target if it makes sense to you. This test
# example assumes there is already a tested running server.
test-client:
	# run each client test
	for t in $(CLIENT_TESTS) ; do \
		if [ -f $$t ] ; then \
			$(DEPLOY_RUNTIME)/bin/perl $$t ; \
			if [ $$? -ne 0 ] ; then \
				exit 1 ; \
			fi \
		fi \
	done

test-server:
	# run each server test
	for t in $(SERVER_TESTS) ; do \
		if [ -f $$t ] ; then \
			echo Running $$t ; \
			$(DEPLOY_RUNTIME)/bin/perl $$t ; \
			if [ $$? -ne 0 ] ; then \
				exit 1 ; \
			fi \
		fi \
	done

test-prod-server:
	# run each prod test
	for t in $(PROD_TESTS) ; do \
		if [ -f $$t ] ; then \
			echo Running $$t ; \
			$(DEPLOY_RUNTIME)/bin/perl $$t ; \
			if [ $$? -ne 0 ] ; then \
				exit 1 ; \
			fi \
		fi \
	done

clean:
	ant clean

$(BIN_DIR)/%: service-scripts/%.pl $(TOP_DIR)/user-env.sh
	$(WRAP_PERL_SCRIPT) '$$KB_TOP/modules/$(CURRENT_DIR)/$<' $@

$(BIN_DIR)/%: service-scripts/%.py $(TOP_DIR)/user-env.sh
	$(WRAP_PYTHON_SCRIPT) '$$KB_TOP/modules/$(CURRENT_DIR)/$<' $@

include $(TOP_DIR)/tools/Makefile.common.rules
