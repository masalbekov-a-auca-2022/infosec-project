#!/bin/bash

#check for root
if [[ $EUID -ne 0 ]]; then
  echo "Please run as root (use sudo)"
  exit 1
fi

add_user() {
  username="$1"
  role="$2"

  #check username format
  if ! [[ "$username" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
    echo "Invalid username: '$username'"
    return 1
  fi

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
      getent group readonly >/dev/null || groupadd readonly
      usermod -aG readonly "$username"
      echo "$username is a visitor with read-only access."
      ;;
    
    editor)
      #editor can write and read, but can not execute
      chmod 755 "$home_dir"
      echo "$username is an editor with read/write access."
      ;;
    
    superman)
      #this guy has full access and can do pretty much everything
      chmod 755 "$home_dir"
      usermod -aG sudo "$username"
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

change_role() {
  username="$1"
  new_role="$2"

  if ! id "$username" &>/dev/null; then
    echo "User $username does not exist."
    return
  fi

  #remove previous group privileges
  gpasswd -d "$username" readonly 2>/dev/null
  deluser "$username" sudo 2>/dev/null

  #apply new role
  add_user "$username" "$new_role"
  echo "Role of $username changed to $new_role."
}

lock_user() {
  username="$1"
  #lock user account
  if id "$username" &>/dev/null; then
    passwd -l "$username"
    echo "User $username locked."
  else
    echo "User $username does not exist."
  fi
}

unlock_user() {
  username="$1"
  #unlock user account
  if id "$username" &>/dev/null; then
    passwd -u "$username"
    echo "User $username unlocked."
  else
    echo "User $username does not exist."
  fi
}

user_info() {
  username="$1"
  #show user info
  if id "$username" &>/dev/null; then
    echo "User info for $username:"
    id "$username"
    grep "^$username:" /etc/passwd
    echo "Home directory permissions:"
    ls -ld "/home/$username"
  else
    echo "User $username does not exist."
  fi
}

set_password() {
  username="$1"
  #set temporary password
  if id "$username" &>/dev/null; then
    temp_pass=$(openssl rand -base64 12)
    echo "$username:$temp_pass" | chpasswd
    echo "Temporary password for $username: $temp_pass"
  else
    echo "User $username does not exist."
  fi
}

list_users() {
  echo "Existing users:"
  #list non-system users
  cut -d: -f1 /etc/passwd | grep -E '^[a-zA-Z]' | grep -vE '^(root|daemon|nobody|sys|sync|games|man|lp|mail|news|uucp|proxy|www-data|backup|list|irc|gnats|systemd|messagebus|_.*)'
}

show_help() {
  echo "Usage:"
  echo "$0 add <username> <role>       # add user with role"
  echo "$0 del <username>              # delete user"
  echo "$0 role <username> <role>      # change user's role"
  echo "$0 lock <username>             # lock user"
  echo "$0 unlock <username>           # unlock user"
  echo "$0 info <username>             # show user info"
  echo "$0 pass <username>             # set temporary password"
  echo "$0 ls                          # list users"
  echo "$0 help                        # show help"
  echo "Roles: restricted, visitor, editor, superman"
}

case "$1" in
  add)
    [[ -z "$2" || -z "$3" ]] && echo "Missing username or role." && show_help || add_user "$2" "$3"
    ;;
  del)
    [[ -z "$2" ]] && echo "Missing username." && show_help || delete_user "$2"
    ;;
  role)
    [[ -z "$2" || -z "$3" ]] && echo "Missing username or role." && show_help || change_role "$2" "$3"
    ;;
  lock)
    [[ -z "$2" ]] && echo "Missing username." && show_help || lock_user "$2"
    ;;
  unlock)
    [[ -z "$2" ]] && echo "Missing username." && show_help || unlock_user "$2"
    ;;
  info)
    [[ -z "$2" ]] && echo "Missing username." && show_help || user_info "$2"
    ;;
  pass)
    [[ -z "$2" ]] && echo "Missing username." && show_help || set_password "$2"
    ;;
  ls)
    list_users
    ;;
  help|*)
    show_help
    ;;
esac
