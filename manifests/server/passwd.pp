# @api private
class postgresql::server::passwd {
  $postgres_password = if $postgresql::server::postgres_password =~ Sensitive {
    $postgresql::server::postgres_password.unwrap
  } else {
    $postgresql::server::postgres_password
  }

  $user              = $postgresql::server::user
  $group             = $postgresql::server::group
  $psql_path         = $postgresql::server::psql_path
  $port              = $postgresql::server::port
  $database          = $postgresql::server::default_database
  $module_workdir    = $postgresql::server::module_workdir

  # psql will default to connecting as $user if you don't specify name
  $_datbase_user_same = $database == $user
  $_dboption = $_datbase_user_same ? {
    false => " --dbname ${shell_escape($database)}",
    default => ''
  }

  if $postgres_password {
    # NOTE: this password-setting logic relies on the pg_hba.conf being
    #  configured to allow the postgres system user to connect via psql
    #  without specifying a password ('ident' or 'trust' security). This is
    #  the default for pg_hba.conf.
    $escaped = postgresql::postgresql_escape($postgres_password)
    $exec_command = "${shell_escape($psql_path)}${_dboption} -c \"ALTER ROLE \\\"${shell_escape($user)}\\\" PASSWORD \${NEWPASSWD_ESCAPED}\""
    exec { 'set_postgres_postgrespw':
      # This command works w/no password because we run it as postgres system
      # user
      command     => $exec_command,
      user        => $user,
      group       => $group,
      logoutput   => true,
      cwd         => $module_workdir,
      environment => [
        "PGPASSWORD=${postgres_password}",
        "PGPORT=${port}",
        "NEWPASSWD_ESCAPED=${escaped}",
      ],
      # With this command we're passing -h to force TCP authentication, which
      # does require a password.  We specify the password via the PGPASSWORD
      # environment variable. If the password is correct (current), this
      # command will exit with an exit code of 0, which will prevent the main
      # command from running.
      unless      => "${psql_path} -h localhost -p ${port} -c 'select 1' > /dev/null",
      path        => '/usr/bin:/usr/local/bin:/bin',
    }
  }
}
