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
  _labelprefix=$1
  _result=$(grep "^${_labelprefix} " /var/lib/os-prober/labels 2>/dev/null || true)

  if [ -z "$_result" ]; then
    return
  else
    echo "$_result" | cut -d' ' -f2
  fi
}

count_next_label() {
  require_tmpdir

  _labelprefix=$1
  _cfor="$(count_for ${_labelprefix})"

  if [ -z "$_cfor" ]; then
    echo "${_labelprefix} 1" >> /var/lib/os-prober/labels
  else
    sed "s/^${_labelprefix} ${_cfor}/${_labelprefix} $(($_cfor + 1))/" /var/lib/os-prober/labels > "$OS_PROBER_TMP/os-prober.tmp"
    mv "$OS_PROBER_TMP/os-prober.tmp" /var/lib/os-prober/labels
  fi
  
  echo "${_labelprefix}${_cfor}"
}

log() {
  logger -t "$(basename $0)" "$@"
}

error() {
  log "error: $@"
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

parse_proc_mounts () {
	while read line; do
		set -- $line
		echo "$(mapdevfs $1) $2 $3"
	done
}

parsefstab () {
	while read line; do
		case "$line" in
			"#"*)
				:	
			;;
			*)
				set -- $line
				echo $1 $2 $3
			;;
		esac
	done
}

linux_mount_boot () {
	partition="$1"
	tmpmnt="$2"

	bootpart=""
	mounted=""
	if [ -e "$tmpmnt/etc/fstab" ]; then
		# Try to mount any /boot partition.
		bootmnt=$(parsefstab < $tmpmnt/etc/fstab | grep " /boot ") || true
		if [ -n "$bootmnt" ]; then
			set -- $bootmnt
			boottomnt=""
			if [ -x "$tmpmnt/bin/mount" ]; then
				smart_mount="$tmpmnt/bin/mount"
			elif [ -x /target/bin/mount ]; then
				smart_mount=/target/bin/mount
			else
				smart_mount=mount
			fi
			if [ -e "$1" ]; then
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
				if $smart_mount -L "$label" -o ro $tmpmnt/boot -t "$3"; then
					mounted=1
					bootpart=$(mount | grep $tmpmnt/boot | cut -d " " -f 1)
				else
					error "failed to mount by label"
				fi
			elif echo "$1" | grep -q "UUID="; then
				debug "mounting boot partition by UUID for linux system on $partition: $1"
				uuid=$(echo "$1" | cut -d = -f 2)
				if $smart_mount -U "$uuid" -o ro $tmpmnt/boot -t "$3"; then
					mounted=1
					bootpart=$(mount | grep $tmpmnt/boot | cut -d " " -f 1)
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
					if mount -o ro "$boottomnt" $tmpmnt/boot -t "$3"; then
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
