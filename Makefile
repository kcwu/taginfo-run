# -----------------------------------
# config
JAIL_NAME=taginfo
JAIL_IP=10.100.100.1

# -----------------------------------
# variable

# note: this path is hardcoded in the code, too.
TOP = /taginfo-run
BUILD_DIR = ./build
DATA_DIR = ./data
REPO_DIR = ./repo

CONF_FILE = ./taginfo-config.json
EXTRACT_FILE = $(BUILD_DIR)/taiwan-latest.osm.pbf
LAST_DB = $(BUILD_DIR)/taginfo-history.db

JAIL_ROOT=/usr/jails/$(JAIL_NAME)
JAIL_TOP=$(JAIL_ROOT)$(TOP)
SUPERVISORD_CONF = /usr/local/etc/supervisord.conf

all:

# run outside jail, need root
create-jail:
	[ -n "$(JAIL_USER)" ]
	[ -n "$(JAIL_UID)" ]
	[ -e /usr/jails ]  # make sure we are outside  jail
	ezjail-admin create $(JAIL_NAME) 'lo1|$(JAIL_IP)'
	[ -e "$(JAIL_ROOT)" ]
	ezjail-admin start $(JAIL_NAME)
	ezjail-admin console -e "pw user add $(JAIL_USER) -u $(JAIL_UID)" $(JAIL_NAME)
	ezjail-admin console -e 'mkdir $(TOP)' $(JAIL_NAME)
	ezjail-admin console -e 'chown $(JAIL_USER) $(TOP)' $(JAIL_NAME)

# run inside jail
init-jail:
	[ ! -e /usr/jails ]  # make sure we are inside jail
	grep nameserver /etc/resolv.conf || echo 'nameserver 8.8.8.8' >> /etc/resolv.conf
	env ASSUME_ALWAYS_YES=yes pkg bootstrap
	sysrc sendmail_msp_queue_enable=NO
	sysrc sendmail_submit_enable=NO
	sysrc sendmail_outbound_enable=NO
	sysrc syslogd_flags="-ss"
	sysrc cron_enable=NO

init-supervisord:
	pkg install -y py27-supervisor
	grep taginfo $(SUPERVISORD_CONF) || \
	    (echo '[include]'; echo 'files = $(TOP)/taginfo.ini') >> $(SUPERVISORD_CONF)
	grep supervisord_enable /etc/rc.conf || \
	    (echo 'supervisord_enable="YES"' >> /etc/rc.conf && service supervisord start)
depend-freebsd:
	pkg install -y wget gmake
	# taginfo
	cd /usr/ports/databases/sqlite3 && make WITH=ICU BATCH=1 install clean
	pkg install -y ruby google-sparsehash icu boost-libs pkgconf bash libgd \
	    rubygem-sqlite3 rubygem-sinatra-r18n rubygem-rack-contrib curl

all-jail:
	[ -e /usr/jails ]  # make sure we are outside  jail
	[ `id -u` != 0 ]   # make sure we are not root
	sudo make create-jail JAIL_NAME=$(JAIL_NAME) JAIL_IP=$(JAIL_IP) JAIL_USER=$(USER) JAIL_UID=`id -u`
	git clone git@github.com:kcwu/taginfo-run.git $(JAIL_TOP)
	sudo ezjail-admin console -e 'make -C $(TOP) init-jail init-supervisord depend-freebsd' $(JAIL_NAME)
	cd $(JAIL_TOP) && make init
	make update-jail JAIL_NAME=$(JAIL_NAME)

update-jail:
	sudo ezjail-admin console -e 'gmake -C $(TOP) update restart' $(JAIL_NAME)

init:
	mkdir -p $(BUILD_DIR) $(DATA_DIR)
	git clone https://github.com/osmcode/libosmium.git
	git clone https://github.com/kcwu/taginfo.git $(REPO_DIR)

code:
	cd $(REPO_DIR)/tagstats && $(MAKE) all

download_extract $(EXTRACT_FILE):
	cd $(BUILD_DIR) && wget -N http://download.geofabrik.de/asia/taiwan-latest.osm.pbf

$(LAST_DB): code $(EXTRACT_FILE) $(CONF_FILE)
	$(REPO_DIR)/sources/update_all.sh $(BUILD_DIR)

update: $(LAST_DB)
	cp $(BUILD_DIR)/taginfo-*.db $(BUILD_DIR)/*/taginfo-*.db $(DATA_DIR)

restart:
	supervisorctl restart taginfo

.PHONY: download_extract $(EXTRACT_FILE)