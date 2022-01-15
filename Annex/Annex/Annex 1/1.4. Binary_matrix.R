Binary_matrix <- function(df1, df2){
  for(i in 1:length((row.names(df1)))){
    for (j in 1:length(df1[i,])){
      for (w in 1:length(colnames(df2))){
        if (df1[i,j] != 0 & df2[i, w] != 1 & df1[i,j] == colnames(df2)[w]){df2[i,w] = 1}
        else if (df2[i,w]== 1){df2[i,w]= 1}
        else {df2[i,w]= 0}}}}
  return(df2)}

