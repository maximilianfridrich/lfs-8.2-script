function is_user
{
  if [ $(whoami) != "$1" ]
  then
    echo "!! Fatal Error 2: Must be run as $1"
    exit 2
  fi
}
