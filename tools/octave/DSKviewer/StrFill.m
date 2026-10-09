function String = StrFill (String, Length)
% Add trailing spaces to get nice formatting when several instances are on the same line
while length(String) < Length
  String = cstrcat(String, " ");
end

end
