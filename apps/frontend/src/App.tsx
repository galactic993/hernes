import { AuthArea } from './auth/AuthArea'
import { SearchForm } from './features/prod-quote/SearchForm'

export function App() {
  return (
    <main>
      <header>
        <h1>制作見積書作成 &lt;トップ画面&gt;</h1>
        <AuthArea />
      </header>
      <SearchForm />
    </main>
  )
}
