count_for() {
  local labelprefix=$1
  local result=$(grep "^${labelprefix} " /var/lib/os-prober/labels)

  if [ -z "$result" ]; then
    return
  else
    echo "$result" | cut -d' ' -f2
  fi
}

count_next_label() {
  local labelprefix=$1
  local cfor="$(count_for ${labelprefix})"

  if [ -z "$cfor" ]; then
    echo "${labelprefix} 1" >> /var/lib/os-prober/labels
  else
    sed "s/^${labelprefix} ${cfor}/${labelprefix} $(($cfor + 1))/" /var/lib/os-prober/labels > /tmp/os-prober.tmp
    mv /tmp/os-prober.tmp /var/lib/os-prober/labels
  fi
  
  echo "${labelprefix}${cfor}"
}
