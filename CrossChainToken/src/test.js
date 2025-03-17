let i = 12;
const symbol = "*";
let volume = 0;

while(volume < i){
    // output = symbol * i; // this will error because multiply string with int is prohibited
    output = symbol.repeat(i);
    // space = " ".repeat(volume - i);
    console.log( output);

    volume++;
}
