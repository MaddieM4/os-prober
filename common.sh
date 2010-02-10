newns () {
  [ "$OS_PROBER_NEWNS" ] || exec /usr/lib/os-prober/newns "$0" "$@"
}

require_tmpdir() {
  if [ -z "$OS_PROBER_TMP" ]; then
    if type mktemp >/dev/null 2>&1; then
      export OS_PROBER_TMP="$(mktemp -d /tmp/os-prober.XXXXXX)"
      trap "rm -rf $OS_PROBER_TMP" EXIT HUP INT QUIT TERM
    else
      export OS_PROBER_TMP=/tmp
    fi
  fi
}

count_for() {
  _labelprefix="$1"
  _result=$(grep "^${_labelprefix} " /var/lib/os-prober/labels 2>/dev/null || true)

  if [ -z "$_result" ]; then
    return
  else
    echo "$_result" | cut -d' ' -f2
  fi
}

count_next_label() {
  require_tmpdir

  _labelprefix="$1"
  _cfor="$(count_for "${_labelprefix}")"

  if [ -z "$_cfor" ]; then
    echo "${_labelprefix} 1" >> /var/lib/os-prober/labels
  else
    sed "s/^${_labelprefix} ${_cfor}/${_labelprefix} $(($_cfor + 1))/" /var/lib/os-prober/labels > "$OS_PROBER_TMP/os-prober.tmp"
    mv "$OS_PROBER_TMP/os-prober.tmp" /var/lib/os-prober/labels
  fi
  
  echo "${_labelprefix}${_cfor}"
}

progname=
cache_progname() {
  case $progname in
    '')
      progname="$(basename "$0")"
      ;;
  esac
}

log() {
  cache_progname
  logger -t "$progname" "$@"
}

error() {
  log "error: $@"
}

warn() {
  log "warning: $@"
}

debug() {
  log "debug: $@"
}

result () {
  log "result:" "$@"
  echo "$@"
}

# shim to make it easier to use os-prober outside d-i
if ! type mapdevfs >/dev/null 2>&1; then
  mapdevfs () {
    readlink -f "$1"
  }
fi

item_in_dir () {
	if [ "$1" = "-q" ]; then
		q="-q"
		shift 1
	else
		q=""
	fi
	# find files with any case
	ls -1 "$2" | grep $q -i "^$1$"
}

# We can't always tell the filesystem type up front, but if we have the
# information then we should use it. Note that we can't use block-attr here
# as it's only available in udebs.
fs_type () {
	if (export PATH="/lib/udev:$PATH"; type vol_id) >/dev/null 2>&1; then
		PATH="/lib/udev:$PATH" vol_id --type "$1" 2>/dev/null
	elif type blkid >/dev/null 2>&1; then
		blkid -o value -s TYPE "$1" 2>/dev/null
	else
		return 0
	fi
}

parse_proc_mounts () {
	while read -r line; do
		set -- $line
		printf '%s %s %s\n' "$(mapdevfs "$1")" "$2" "$3"
	done
}

parsefstab () {
	while read -r line; do
		case "$line" in
			"#"*)
				:	
			;;
			*)
				set -- $line
				printf '%s %s %s\n' "$1" "$2" "$3"
			;;
		esac
	done
}

unescape_mount () {
	printf %s "$1" | \
		sed 's/\\011/	/g; s/\\012/\n/g; s/\\040/ /g; s/\\134/\\/g'
}

linux_mount_boot () {
	partition="$1"
	tmpmnt="$2"

	bootpart=""
	mounted=""
	if [ -e "$tmpmnt/etc/fstab" ]; then
		# Try to mount any /boot partition.
		bootmnt=$(parsefstab < "$tmpmnt/etc/fstab" | grep " /boot ") || true
		if [ -n "$bootmnt" ]; then
			set -- $bootmnt
			boottomnt=""

			# Try to map labels and UUIDs ourselves if possible,
			# so that we can check whether they're already
			# mounted somewhere else.
			if echo "$1" | grep -q "LABEL="; then
				label="$(echo "$1" | cut -d = -f 2)"
				if [ -h "/dev/disk/by-label/$label" ]; then
					shift
					set -- "$(readlink -f "/dev/disk/by-label/$label")" "$@"
					debug "mapped LABEL=$label to $1"
				fi
			fi
			if echo "$1" | grep -q "UUID="; then
				uuid="$(echo "$1" | cut -d = -f 2)"
				if [ -h "/dev/disk/by-uuid/$uuid" ]; then
					shift
					set -- "$(readlink -f "/dev/disk/by-uuid/$uuid")" "$@"
					debug "mapped UUID=$uuid to $1"
				fi
			fi
			tmppart="$1"
			shift
			set -- "$(mapdevfs "$tmppart")" "$@"

			# This is an awful hack and isn't guaranteed to
			# work, but is the best we can do until busybox
			# mount supports -L/-U.
			smart_ldlp=
			smart_mount=mount
			if mount --help 2>&1 | head -n1 | grep -iq busybox; then
				if [ -x /target/bin/mount ]; then
					smart_ldlp=/target/lib
					smart_mount=/target/bin/mount
				fi
			fi
			if grep -q "^$1 " "$OS_PROBER_TMP/mounted-map"; then
				bindfrom="$(grep "^$1 " "$OS_PROBER_TMP/mounted-map" | head -n1 | cut -d " " -f 2)"
				bindfrom="$(unescape_mount "$bindfrom")"
				if [ "$bindfrom" != "$tmpmnt/boot" ]; then
					if mount --bind "$bindfrom" "$tmpmnt/boot"; then
						mounted=1
						bootpart="$1"
					else
						debug "failed to bind-mount $bindfrom onto $tmpmnt/boot"
					fi
				fi
			fi
			if [ "$mounted" ]; then
				:
			elif [ -e "$1" ]; then
				bootpart="$1"
				boottomnt="$1"
			elif [ -e "$tmpmnt/$1" ]; then
				bootpart="$1"
				boottomnt="$tmpmnt/$1"
			elif [ -e "/target/$1" ]; then
				bootpart="$1"
				boottomnt="/target/$1"
			elif echo "$1" | grep -q "LABEL="; then
				debug "mounting boot partition by label for linux system on $partition: $1"
				label=$(echo "$1" | cut -d = -f 2)
				if LD_LIBRARY_PATH=$smart_ldlp $smart_mount -L "$label" -o ro "$tmpmnt/boot" -t "$3"; then
					mounted=1
					bootpart=$(mount | grep "$tmpmnt/boot" | cut -d " " -f 1)
				else
					error "failed to mount by label"
				fi
			elif echo "$1" | grep -q "UUID="; then
				debug "mounting boot partition by UUID for linux system on $partition: $1"
				uuid=$(echo "$1" | cut -d = -f 2)
				if LD_LIBRARY_PATH=$smart_ldlp $smart_mount -U "$uuid" -o ro "$tmpmnt/boot" -t "$3"; then
					mounted=1
					bootpart=$(mount | grep "$tmpmnt/boot" | cut -d " " -f 1)
				else
					error "failed to mount by UUID"
				fi
			else
				bootpart=""
			fi

			if [ ! "$mounted" ]; then
				if [ -z "$bootpart" ]; then
					debug "found boot partition $1 for linux system on $partition, but cannot map to existing device"
				else
					debug "found boot partition $bootpart for linux system on $partition"
					if mount -o ro "$boottomnt" "$tmpmnt/boot" -t "$3"; then
						mounted=1
					else
						error "failed to mount $boottomnt on $tmpmnt/boot"
					fi
				fi
			fi
		fi
	fi
	if [ -z "$bootpart" ]; then
		bootpart="$partition"
	fi
	if [ -z "$mounted" ]; then
		mounted=0
	fi

	echo "$bootpart $mounted"
}
