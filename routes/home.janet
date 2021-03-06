(import joy :prefix "")
(import ../helpers :prefix "")
(import http)
(import cipher)
(import json)
(import moondown)


(defn index [request]
  [:vstack {:align-x "center" :stretch "" :spacing "l"
            :x-data (string/format "searcher('%s')" (url-for :home/searches))}
    [:h1
     [:span "JanetDocs is a community documentation site for the "]
     [:a {:href "https://janet-lang.org"} "janet programming language"]]
    [:input {:type "text" :name "token" :placeholder "search docs"
             :autofocus ""
             :style "width: 100%"
             :x-model "token"
             :x-on:keyup.debounce "search()"
             :x-on:keydown.enter.prevent "go()"}]
    [:div {:x-html "results" :style "width: 100%"}
     "Loading..."]])


(defn searches [request]
  (let [body (request :body)
        token (body :token)
        bindings (db/query (slurp "db/sql/search.sql") [(string token "%")])]
    (if (blank? token)
      (text/html [:div])
      (text/html
        [:vstack {:spacing "xl"}
         (foreach [binding bindings]
           [:vstack {:spacing "xs"}
            [:a {:class "binding" :href (binding-show-url binding)}
             (binding :name)]
            [:pre
             [:code {:class "clojure"}
               (binding :docstring)]]])]))))


(defn github-auth [request]
  (def code (get-in request [:query-string :code]))

  (def result (http/post "https://github.com/login/oauth/access_token"
                         (string/format "client_id=%s&client_secret=%s&code=%s"
                                        (env :github-client-id)
                                        (env :github-client-secret)
                                        code)
                         :headers {"Accept" "application/json"}))


  (def result (json/decode (result :body) true true))

  (def access-token (get result :access_token))

  (def auth-response (http/get "https://api.github.com/user"
                               :headers {"Authorization" (string "token " access-token)}))

  (def auth-result (json/decode (auth-response :body) true true))

  (var account (db/find-by :account :where {:login (auth-result :login)}))

  (unless account
    (set account (db/insert :account {:login (auth-result :login)
                                      :access-token access-token})))

  (db/update :account (account :id) {:access-token access-token})

  (-> (redirect-to :home/index)
      (put-in [:session :login] (account :login))))
