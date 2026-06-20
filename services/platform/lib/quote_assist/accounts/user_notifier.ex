defmodule QuoteAssist.Accounts.UserNotifier do
  import Swoosh.Email

  alias QuoteAssist.Accounts.User
  alias QuoteAssist.Mailer

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"QuoteAssist", "contact@example.com"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    deliver(user.email, "Update email instructions", """

    ==============================

    Hi #{user.email},

    You can change your email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver an alert to the user's **old** address when an email change is requested
  (R9-recovery), so a hijacked session can't silently move the account — the real owner
  gets a heads-up even though the confirm link goes to the new address.
  """
  def deliver_email_change_alert(old_email, new_email) do
    deliver(old_email, "Your QuoteAssist email is being changed", """

    ==============================

    Hi #{old_email},

    Someone requested to change the email on your QuoteAssist account to:

    #{new_email}

    The change only takes effect once it's confirmed from that new address. If this
    wasn't you, change your password immediately — your account may be compromised.

    ==============================
    """)
  end

  @doc """
  Deliver password-reset instructions (R9-recovery). The link targets the platform host
  so it keeps working even if the user's tenant is suspended.
  """
  def deliver_reset_password_instructions(user, url) do
    deliver(user.email, "Reset your QuoteAssist password", """

    ==============================

    Hi #{user.email},

    You can reset your password by visiting the URL below:

    #{url}

    This link expires in 60 minutes and can only be used once. If you didn't request a
    password reset, please ignore this email — your password won't change.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to log in with a magic link.
  """
  def deliver_login_instructions(user, url) do
    case user do
      %User{confirmed_at: nil} -> deliver_confirmation_instructions(user, url)
      _ -> deliver_magic_link_instructions(user, url)
    end
  end

  defp deliver_magic_link_instructions(user, url) do
    deliver(user.email, "Log in instructions", """

    ==============================

    Hi #{user.email},

    You can log into your account by visiting the URL below:

    #{url}

    If you didn't request this email, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver the self-service owner onboarding link (R5-selfreg). The link sets a
  password and confirms the email in one step.
  """
  def deliver_onboarding_instructions(user, url) do
    deliver(user.email, "Finish setting up your QuoteAssist workspace", """

    ==============================

    Hi #{user.email},

    Your QuoteAssist workspace is ready. Finish setting up your account — set a
    password and confirm your email — by visiting the URL below:

    #{url}

    This link expires in 7 days. If you didn't create a QuoteAssist workspace,
    please ignore this email.

    ==============================
    """)
  end

  defp deliver_confirmation_instructions(user, url) do
    deliver(user.email, "Confirmation instructions", """

    ==============================

    Hi #{user.email},

    You can confirm your account by visiting the URL below:

    #{url}

    If you didn't create an account with us, please ignore this.

    ==============================
    """)
  end
end
