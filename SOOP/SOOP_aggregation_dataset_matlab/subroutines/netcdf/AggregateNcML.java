import ucar.nc2.*;
import ucar.nc2.dataset.*;
import ucar.nc2.ncml.*;
import java.io.FileInputStream;

class AggregateNcML {

	public static void main(String[] args) {

		String ncml_filename = args[0];
		String fileout_name = args[1];

		System.out.println( "ncml_filename = '" + ncml_filename + "'" );
		System.out.println( "fileout_name  = '" + fileout_name + "'" );

		try {
			FileInputStream fis = new FileInputStream( ncml_filename );

			NetcdfDataset ncd = NcMLReader.readNcML(fis, null);
			NetcdfFile ncdnew = FileWriter.writeToFile(ncd, fileout_name, true);
			ncd.close();
			ncdnew.close();
		}
		catch (Exception e) {
			
			System.out.println( "Exception" + e.getMessage() );
			e.printStackTrace();
		}
	}
}
