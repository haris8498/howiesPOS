import { Body, Controller, Get, Post, HttpCode, HttpStatus } from '@nestjs/common';
import { ApiOperation, ApiTags, ApiResponse, ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString } from 'class-validator';
import { PrinterService } from './printer.service';

export class PrintRequestDto {
  @ApiProperty({ description: 'Target printer name or port', example: 'POS Receipt Printer' })
  @IsString()
  @IsNotEmpty()
  printerName!: string;

  @ApiProperty({ description: 'Base64 encoded raw ESC/POS bytecode' })
  @IsString()
  @IsNotEmpty()
  base64Data!: string;

  @ApiProperty({ description: 'Document name in spooler queue', required: false })
  @IsString()
  @IsOptional()
  docName?: string;
}

@ApiTags('Printer')
@Controller('printer')
export class PrinterController {
  constructor(private readonly printerService: PrinterService) {}

  @Get('list')
  @ApiOperation({ summary: 'Get list of available thermal printers and ports on host' })
  @ApiResponse({ status: 200, description: 'List of physical & spooler printers' })
  async getPrinterList() {
    const data = await this.printerService.getAvailablePrinters();
    return {
      success: true,
      data,
    };
  }

  @Post('print')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Send direct raw ESC/POS binary data to thermal printer' })
  async printReceipt(@Body() body: PrintRequestDto) {
    const { printerName, base64Data, docName } = body;
    const success = await this.printerService.printRaw(printerName, base64Data, docName);
    return {
      success,
      message: success
        ? `Print job successfully sent to [${printerName}]`
        : `Failed to print to [${printerName}]. Please check printer power and USB connection.`,
    };
  }

  @Post('ensure-pos')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Ensure POS Receipt Printer spooler queue is registered' })
  async ensurePosPrinter() {
    const success = await this.printerService.ensurePosPrinter();
    return {
      success,
      message: success ? 'POS Receipt Printer ready' : 'Could not configure printer queue',
    };
  }
}
