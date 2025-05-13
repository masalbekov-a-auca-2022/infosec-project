#!/bin/bash

#check for root
if [[ $EUID -ne 0 ]]; then
  echo "Please run as root (use sudo)"
  exit 1
fi

add_user() {
  username="$1"
  role="$2"

  if id "$username" &>/dev/null; then
    echo "User $username already exists."
    return
  fi

  useradd -m -s /bin/bash "$username"
  echo "$username created."

  home_dir="/home/$username"

  chmod 700 "$home_dir"
  chown "$username:$username" "$home_dir"

  case "$role" in
    restricted)
      #restricted can only access their home dir, no group/world permissions
      chmod 700 "$home_dir"
      echo "$username is a restricted user."
      ;;
    
    visitor)
      #visitor is reader, he has access to read
      chmod 755 "$home_dir"
      usermod -aG readonly "$username" 2>/dev/null || groupadd readonly && usermod -aG readonly "$username"
      echo "$username is a visitor with read-only access."
      ;;
    
    editor)
      #editor can write and read, but can not execute
      chmod 755 "$home_dir"
      echo "$username is an editor with read/write access."
      ;;
    
    superman)
      #this guy has full access and can do pretty much everything
      usermod -aG sudo "$username"
      chmod 755 "$home_dir"c
      echo "$username is a superman with sudo privileges."
      ;;
    
    *)
      echo "Unknown role. Only creating user without extra permissions."
      ;;
  esac
}

delete_user() {
  username="$1"
  if id "$username" &>/dev/null; then
    deluser --remove-home "$username"
    echo "User $username deleted."
  else
    echo "User $username does not exist."
  fi
}

list_users() {
  echo "Existing users:"
  cut -d: -f1 /etc/passwd | grep -E '^[a-zA-Z]' | grep -vE '^(root|daemon|nobody|sys|sync|games|man|lp|mail|news|uucp|proxy|www-data|backup|list|irc|gnats|systemd|messagebus|_.*)'
}

show_help() {
  echo "Usage:"
  echo "$0 add <username> <role>"
  echo "$0 del <username>"
  echo "$0 ls"
  echo "Roles: restricted, visitor, editor, superman"
}

case "$1" in
  add)
    if [[ -z "$2" || -z "$3" ]]; then
      echo "Missing username or role."
      show_help
    else
      add_user "$2" "$3"
    fi
    ;;
  
  del)
    if [[ -z "$2" ]]; then
      echo "Missing username."
      show_help
    else
      delete_user "$2"
    fi
    ;;

  ls)
    list_users
    ;;

  help|*)
    show_help
    ;;
esac
