DAVFS_MP=	${HOME}/.yadisk-davfs
DISK_FOLDER=	${HOME}/YandexDisk

default:
	echo "No default make target, see README"

root-setup:
# README.manual: 0, 1, 3, 4, 6
# check davfs2
	@which mount.davfs > /dev/null || (echo " *** Need davfs support, try installing davfs2 package" && exit 1)
# perl 5.10
	@perl -M5.10.0 -e1 > /dev/null || (echo " *** Need perl 5.10 or higher" && exit 1)
# unison
	@which unison > /dev/null || (echo " *** Need unison, try installing unison package" && exit 1)
# we need libidn11-dev for XMPP
	@test -r `pkg-config --variable=includedir libidn`/idna.h || (echo " *** Need libidn headers, try installing libidn11-dev package" && exit 1)
	@echo "The system has davfs2, perl 5.10, libidn-dev and unison, good."

	@test `id -u` -eq 0 || (echo " *** Need to run 'make root-setup' as root with sudo" && exit 1)

	@if which curl > /dev/null; then \
		curl -L http://cpanmin.us | perl - --self-upgrade && \
		cpanm uni::perl autodie Config::Tiny AnyEvent::Inotify::Simple EV AnyEvent::XMPP Linux::Proc::Mounts && \
		echo "Installed Perl dependencies." || exit 1; \
	else \
		echo " *** No curl found, install required Perl packages manually, see README.manual "; \
	fi

	@echo "https://webdav.yandex.ru	${DAVFS_MP}	davfs	noauto,user	0 0" >> /etc/fstab
	@echo "Added fstab entry."

	@echo "You need to enable davfs mounting for normal users. Press Enter" && read DUMMY
	@which dpkg-reconfigure > /dev/null && dpkg-reconfigure davfs2

	@usermod -a -G davfs2 ${SUDO_USER}
	@echo "Added ${SUDO_USER} to davfs2 group."

	@echo "Now run 'make YANDEX_LOGIN=<login> YANDEX_PASSWORD=<password> setup' to finish configuration"


setup:
# README.manual: 2, 2.5, 4.5, 4.6, 5, 5.5
	@test ${YANDEX_LOGIN} || (echo " *** Need YANDEX_LOGIN variable" && exit 1)
	@test ${YANDEX_PASSWORD} || (echo " *** Need YANDEX_PASSWORD variable" && exit 1)

	@mkdir -p ${HOME}/.davfs2
	@echo "${DAVFS_MP}	${YANDEX_LOGIN}	${YANDEX_PASSWORD}" >> ${HOME}/.davfs2/secrets
	@chown ${USER}:${USER} ${HOME}/.davfs2/secrets
	@chmod 600 ${HOME}/.davfs2/secrets
	@echo "Added davfs credentials."

	@mkdir -p ${DISK_FOLDER}/Documents
	@echo "Created ${DISK_FOLDER}."

	@echo "[auth]" >> ${HOME}/.yadiskrc
	@chmod 600 ${HOME}/.yadiskrc
	@echo "login=${YANDEX_LOGIN}" >> ${HOME}/.yadiskrc
	@echo "password=${YANDEX_PASSWORD}" >> ${HOME}/.yadiskrc
	@echo "[paths]" >> ${HOME}/.yadiskrc
	@echo "webdav=${DAVFS_MP}" >> ${HOME}/.yadiskrc
	@echo "folder=${DISK_FOLDER}" >> ${HOME}/.yadiskrc
	@echo "Created ${HOME}/.yadiskrc with your config."

	@echo "Now you may run yadisk-sync.pl."
