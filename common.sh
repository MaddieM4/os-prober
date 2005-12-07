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
  _labelprefix=$1
  _cfor="$(count_for ${_labelprefix})"

  if [ -z "$_cfor" ]; then
    echo "${_labelprefix} 1" >> /var/lib/os-prober/labels
  else
    sed "s/^${_labelprefix} ${_cfor}/${_labelprefix} $(($_cfor + 1))/" /var/lib/os-prober/labels > /tmp/os-prober.tmp
    mv /tmp/os-prober.tmp /var/lib/os-prober/labels
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
    echo "$1"
  }
fi
