import { SignInButton, SignedIn, SignedOut, UserButton } from '@clerk/clerk-react'

/** 未ログイン時はサインイン導線、ログイン時はユーザーメニューを表示する。 */
export function AuthArea() {
  return (
    <div className="auth-area">
      <SignedOut>
        <SignInButton mode="modal" />
      </SignedOut>
      <SignedIn>
        <UserButton />
      </SignedIn>
    </div>
  )
}
