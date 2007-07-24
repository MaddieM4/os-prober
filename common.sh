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
