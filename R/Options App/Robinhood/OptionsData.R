###Port to R6
#' Get instrument url.
#'
#' Helper method to get a ticker's instrument url for API requests.
#' @param  ticker equity ticker symbol. Must be capitalized.
#' @param header Auth header returned by initialized robinhoodUser. Generated by robinhoodUser$account$user$authHeader.
get_instrument_url = function(ticker,header){
  res <- httr::GET(paste("https://api.robinhood.com/fundamentals/", ticker, "/",sep = ""), httr::add_headers(.headers=header))
  instrumentURL <- httr::content(res)$instrument
  return(instrumentURL)
}  

get_option_instrument_info = function(instrumentURL) {
  res <- httr::GET(instrumentURL)
  instrument_result<-content(res)
  #issue_date<-instrument_result$issue_date
  strike_price<-instrument_result$strike_price
  expiration_date<-instrument_result$expiration_date
  #created_at<-instrument_result$created_at
  type<-instrument_result$type
  chain_symbol<-instrument_result$chain_symbol
  id<-instrument_result$id
  
  option_info<-data.frame(Ticker=chain_symbol,Expiry=expiration_date,Type=type,Strike=strike_price)
  return(option_info)
}


get_option_chain<-function(ticker,header){
  instrumentURL<-get_instrument_url(ticker,header)  
  instrumentID<-strsplit(instrumentURL,"/")[[1]][5]
  url<-paste0("https://api.robinhood.com/options/chains/?equity_instrument_ids=",instrumentID)
  res<-GET(url,add_headers(.headers=header))
  results<-content(res)$results
  #results<-results[[1]]
  results<-results[[2]]
  
  results_list_names<-c("can_open_position","symbol","trade_value_multiplier","underlying_instruments",
                        "expiration_dates","cash_component","min_ticks","id")
  chain_id<-results$id
  expiration_dates<-results$expiration_dates
  expiration_dates<-unlist(expiration_dates)
  toReturn<-list(chain_id,expiration_dates)
  names(toReturn)<-c("chain_id","expiration_dates")
return(toReturn)  
}

 
options_instruments_in_chain<-function(ticker,header){
  option_chain<-get_option_chain(ticker,header)
  chain_id<-option_chain$chain_id
  expiration_dates<-option_chain$expiration_dates
  
  issue_date<-NULL
  strike_price<-NULL
  state<-NULL
  url<-NULL
  expiration_date<-NULL
  created_at<-NULL
  updated_at<-NULL
  type<-NULL
  chain_symbol<-NULL
  tradability<-NULL
  state<-NULL
  id<-NULL

  NEXTURL <- paste0("https://api.robinhood.com/options/instruments/?chain_id=",chain_id,"&tradability=tradable&state=active")
  chain_id<-NULL
  while(is.null(NEXTURL)!=T){
    res <- httr::GET(NEXTURL, httr::add_headers(.headers=header))
    NEXTURL<-httr::content(res)$`next`


    for (result in httr::content(res)$results) {
        issue_date<-c(issue_date,result$issue_date)
        strike_price<-c(strike_price,result$strike_price)
        state<-c(state,result$state)
        url<-c(url,result$url)
        expiration_date<-c(expiration_date,result$expiration_date)
        created_at<-c(created_at,result$created_at)
        chain_id<-c(chain_id,result$chain_id)
        type<-c(type,result$type)
        chain_symbol<-c(chain_symbol,result$chain_symbol)
        tradability<-c(tradability,result$tradability)
        state<-c(state,result$state)
        id<-c(id,result$id)
    }
  }
  options_in_chain<-data.frame(Ticker=chain_symbol,Expiry=expiration_date, Type=type, Strike=strike_price,stringsAsFactors = F)
  toReturn<-list(options_in_chain=options_in_chain,instrument_ids=id,urls=url)
 return(toReturn) 
}

## Return current options data for a given tickers instrument urls filtered by contract type and  expiry  
filtered_options_data<-function(instrument_urls,header){

  instrument<-instrument_urls
  #### Chunk instrument url - 50 urls per request
  max <- 50
  x <- seq_along(instrument)
  chunked_instrument <- split(instrument, ceiling(x/max))
  chunked_params<-NULL
  for (i in 1:length(chunked_instrument)){
    chunked_params[i]<-paste0(chunked_instrument[[i]],collapse=",")
  }
  
  option_data<-NULL
  for (j in 1:length(chunked_params)){
    params<-list(instruments=chunked_params[j])
    url<-"https://api.robinhood.com/marketdata/options/"
    res<-httr::GET(url,query=params,add_headers(.headers=c('Accept'="*/*",
                                                           'Accept-Encoding'='gzip, deflate',
                                                           'Accept-Langauge'='en;q=1, fr;q=0.9, de;q=0.8, ja;q=0.7, nl;q=0.6, it;q=0.5',
                                                           'User-Agent'='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/68.0.3440.106 Safari/537.36',
                                                           header)))
    results<-content(res)$results
    
    for (k in 1:length(results)){
      if(is.null(results[[k]])!=T){
        instrumentURL<-results[[k]]$instrument
        instrument_info<-get_option_instrument_info(instrumentURL)
        dat<-results[[k]]
        dat<-as.character(dat)
        names(dat)<-names(results[[k]])
        dat<-as.data.frame(t(dat))
        dat<-subset(dat, select=-c(instrument))
        option_dat<-cbind(instrument_info,dat)
        option_data<-rbind(option_data,option_dat)
        
      }
    }
    
  }
  return(option_data)
}

## Get options strategy quotes - requires distinct instrument_urls composing strategy, ratio, and type (long/short)
get_options_strategy_quote<-function(instrument_urls,types,ratios){
  url<-"https://api.robinhood.com/marketdata/options/strategy/quotes/"
  params<-list(instruments="https://api.robinhood.com/options/instruments/57da5f0e-008b-4da0-88f9-55b4c6a65596/,https://api.robinhood.com/options/instruments/0f3ab07a-3ebb-43ee-94ba-2cf51280ffd1/",
               ratios="1,1",types="long,short")
  
  res<-httr::GET(url,query=params,add_headers(.headers=c('Accept'="*/*",
                                                         'Accept-Encoding'='gzip, deflate',
                                                         'Accept-Langauge'='en;q=1, fr;q=0.9, de;q=0.8, ja;q=0.7, nl;q=0.6, it;q=0.5',
                                                         'User-Agent'='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/68.0.3440.106 Safari/537.36',
                                                         header)))
  results<-content(res)  
  adjusted_mark_price<-results$adjusted_mark_price
  ask_price<-results$ask_price
  bid_price<-results$bid_price
  mark_price<-results$mark_price
  last_close_date<-results$previous_close_date
  last_close_price<-results$previous_close_price
  contract_legs<-results$legs
  quote_df<-data.frame(Price=adjusted_mark_price,Mark=mark_price,Ask=ask_price,Bid=bid_price,Last_Close=last_close_price)
  return(list(quote=quote_df,legs=contract_legs))
}

## Return entire dataset for all contracts in a given chain (all expiries and types)
all_options_data_for_chain<-function(ticker,header){
  options_instruments_chain<-options_instruments_in_chain(ticker,header)
  instrument<-options_instruments_chain$urls

  #### Chunk instrument url - 50 urls per request
  max <- 50
  x <- seq_along(instrument)
  chunked_instrument <- split(instrument, floor(x/max))
  chunked_params<-NULL
  for (i in 1:length(chunked_instrument)){
    chunked_params[i]<-paste0(chunked_instrument[[i]],collapse=",")
  }
  
  option_data<-NULL
  for (j in 1:length(chunked_params)){
    params<-list(instruments=chunked_params[j])
    url<-"https://api.robinhood.com/marketdata/options/"
    res<-httr::GET(url,query=params,add_headers(.headers=c('Accept'="*/*",
                                                           'Accept-Encoding'='gzip, deflate',
                                                           'Accept-Langauge'='en;q=1, fr;q=0.9, de;q=0.8, ja;q=0.7, nl;q=0.6, it;q=0.5',
                                                           'User-Agent'='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/68.0.3440.106 Safari/537.36',
                                                           header)))
    results<-content(res)$results
    
    for (k in 1:length(results)){
      if(is.null(results[[k]])!=T){
        instrumentURL<-results[[k]]$instrument
        instrument_info<-get_option_instrument_info(instrumentURL)
        dat<-results[[k]]
        dat<-as.character(dat)
        names(dat)<-names(results[[k]])
        dat<-as.data.frame(t(dat))
        dat<-subset(dat, select=-c(instrument))
        option_dat<-cbind(instrument_info,dat)
        option_data<-rbind(option_data,option_dat)
        
      }
    }
    
  }
  return(option_data)
}

# Return historical options data for filtered instrument urls. Span is a named list with possible intervals.
historical_options_quotes<-function(instrument_urls,span="year",header){
  possible_intervals<-list(day="5minute",week="10minute",year="day","5year"="week")
  #### Chunk instrument url - 50 urls per request
  max <- 5
  x <- seq_along(instrument_urls)
  chunked_instrument <- split(instrument_urls, ceiling(x/max))
  chunked_params<-NULL
  for (i in 1:length(chunked_instrument)){
    chunked_params[i]<-paste0(chunked_instrument[[i]],collapse=",")
  }
  
  historicals_list<-NULL
  for (j in 1:length(chunked_params)){
    params<-list(span=span,interval=possible_intervals[[span]],instruments=chunked_params[j])
    request_url <- "https://api.robinhood.com/marketdata/options/historicals/"
    res<-httr::GET(request_url,query=params,add_headers(.headers=c('Accept'="*/*",
                                                           'Accept-Encoding'='gzip, deflate',
                                                           'Accept-Langauge'='en;q=1, fr;q=0.9, de;q=0.8, ja;q=0.7, nl;q=0.6, it;q=0.5',
                                                           'User-Agent'='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/68.0.3440.106 Safari/537.36',
                                                           header)))
    results<-content(res)$results
    
    for (k in 1:length(results)){
      if(is.null(results[[k]])!=T){
        instrumentURL<-results[[k]]$instrument
        dat<-results[[k]]
        
        data_points<-dat$data_points
        date<-NULL
        open_price<-NULL
        close_price<-NULL
        high_price<-NULL
        low_price<-NULL
        volume<-NULL
        for(l in 1:length(data_points)){
          data_point<-data_points[[l]]
          
          date<-c(date,data_point$begins_at)
          open_price<-c(open_price,data_point$open_price)
          close_price<-c(close_price,data_point$close_price)
          high_price<-c(high_price,data_point$high_price)
          low_price<-c(low_price,data_point$low_price)
          volume<-c(volume,data_point$volume)
        }
        OHLCV<-data.frame(Open=open_price,High=high_price,Low=low_price,Close=close_price,Volume=volume)%>%
          mutate_if(is.character,~as.numeric(.,na.rm=T)) %>%
          mutate_all(funs(replace(., is.na(.), 0)))
        rownames(OHLCV)<-date
        
        historicals_list[[instrumentURL]]<-OHLCV
      }
    }
  }
  return(historicals_list)
}

